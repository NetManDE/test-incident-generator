#!/usr/bin/env python3
"""
Incident Test Data Generator

This script generates synthetic incident test data using various LLM APIs
and exports them to an XLSX file.

Supported LLM APIs:
- Ollama/Custom (via requests)
- OpenAI/ChatGPT (via openai library)
- Google Gemini (via google-generativeai library)

Required dependencies:
pip install pandas openpyxl requests openai google-generativeai
"""

import json
import os
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

try:
    import pandas as pd
except ImportError:
    print("Error: pandas is not installed. Please install with: pip install pandas openpyxl")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

try:
    import google.generativeai as genai
except ImportError:
    genai = None


# ==================== CONFIGURATION ====================

CONFIG_FILE = "config.json"
TEMP_FILE = "temp_incidents.json"
OUTPUT_FILE = "incidents_export.xlsx"
BATCH_SIZE = 5  # Default, will be overridden from config if present
NUM_WORKERS = 3  # Default number of parallel workers, will be overridden from config if present
DEBUG = False  # Global debug flag, set via command line argument
progress_lock = threading.Lock()  # Lock for thread-safe progress updates

# The 21 columns in the desired order
COLUMN_NAMES = [
    "Number",
    "Top-Category",
    "Sub-Category",
    "Category",
    "Effort",
    "State",
    "Correlation ID",
    "Short Description",
    "Long Description",
    "Created",
    "Opened",
    "Closed",
    "Priority",
    "Urgency",
    "Impact",
    "Assignment group",
    "Resolution code",
    "Resolution notes",
    "Resolve time",
    "Business duration",
    "Business resolve time"
]

# System prompt for LLM generation
SYSTEM_PROMPT = """You are an expert in IT Service Management and generate realistic incident test data.

IMPORTANT: You MUST respond in English. ALL field names and values must be in ENGLISH.

Generate incidents with the following characteristics:
- ALL incidents must have State="Closed" (REQUIRED)
- Realistic IT problems (Hardware, Software, Network, Access issues, etc.)
- ALL incidents must have a Closed date (since State=Closed)
- ALL incidents must have Resolution code (e.g., "Solved (Permanently)", "Solved (Work Around)")
- ALL incidents must have Resolution notes (detailed explanation of how it was resolved)
- ALL incidents must have Resolve time (minutes between Opened and Closed)
- ALL incidents must have Business resolve time (business minutes to resolution)
- Variety in categories, priorities, and assignment groups
- Realistic timestamps (Created < Opened < Closed)
- Business duration and resolution times in minutes
- ALL content in ENGLISH language

Critical: Respond ONLY with a valid JSON array. No additional explanations or formatting. Use ONLY English field names as specified."""


# ==================== LOAD CONFIG ====================

def load_config() -> Optional[Dict[str, Any]]:
    """
    Loads configuration from config.json if available.

    Returns:
        Dict with configuration or None if not available
    """
    if not os.path.exists(CONFIG_FILE):
        return None

    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            config = json.load(f)

        # Remove comment fields (starting with _)
        cleaned_config = {}
        for key, value in config.items():
            if not key.startswith('_'):
                if isinstance(value, dict):
                    cleaned_config[key] = {k: v for k, v in value.items() if not k.startswith('_')}
                else:
                    cleaned_config[key] = value

        return cleaned_config

    except Exception as e:
        print(f"\n⚠ Warning: Error loading {CONFIG_FILE}: {e}")
        return None


# ==================== LLM CLIENT SELECTION ====================

def get_llm_client(config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Loads LLM client based on configuration or asks user interactively.

    Args:
        config: Optional, pre-loaded configuration

    Returns:
        Dict with 'type' (str) and 'client' (Any) keys
    """
    print("\n" + "="*60)
    print("INCIDENT TEST DATA GENERATOR")
    print("="*60)

    # Try to use config
    if config and "llm_provider" in config:
        provider = config["llm_provider"]
        print(f"\n✓ Configuration found: {CONFIG_FILE}")
        print(f"  Provider: {provider}")

        # Ask if config should be used
        use_config = input("\nDo you want to use this configuration? (y/n) [y]: ").strip().lower()
        if use_config == '' or use_config == 'y':
            try:
                if provider == "ollama":
                    ollama_config = config.get("ollama", {})
                    url = ollama_config.get("url")
                    model = ollama_config.get("model")

                    if not url or not model:
                        print("✗ Incomplete Ollama configuration")
                    else:
                        print(f"  URL: {url}")
                        print(f"  Model: {model}")
                        return {
                            "type": "ollama",
                            "url": url,
                            "model": model
                        }

                elif provider == "openai":
                    if OpenAI is None:
                        print("✗ Error: openai library is not installed.")
                        print("  Install with: pip install openai")
                    else:
                        openai_config = config.get("openai", {})
                        api_key = openai_config.get("api_key")
                        model = openai_config.get("model", "gpt-3.5-turbo")

                        if not api_key:
                            print("✗ OpenAI API key missing in configuration")
                        else:
                            print(f"  Model: {model}")
                            client = OpenAI(api_key=api_key)
                            return {
                                "type": "openai",
                                "client": client,
                                "model": model
                            }

                elif provider == "gemini":
                    if genai is None:
                        print("✗ Error: google-generativeai library is not installed.")
                        print("  Install with: pip install google-generativeai")
                    else:
                        gemini_config = config.get("gemini", {})
                        api_key = gemini_config.get("api_key")
                        model = gemini_config.get("model", "gemini-2.0-flash-live")

                        if not api_key:
                            print("✗ Gemini API key missing in configuration")
                        else:
                            print(f"  Model: {model}")
                            genai.configure(api_key=api_key)
                            client = genai.GenerativeModel(model)
                            return {
                                "type": "gemini",
                                "client": client,
                                "model": model
                            }

                else:
                    print(f"✗ Unknown provider: {provider}")

            except Exception as e:
                print(f"✗ Error loading configuration: {e}")

        print("\n→ Continuing with manual input...\n")

    # Manual input (if no config or config usage declined)
    if not config or "llm_provider" not in config:
        print(f"\n⚠ No configuration found ({CONFIG_FILE})")
        print("  Tip: Copy config.json.example to config.json and fill in your API keys\n")

    print("\nPlease select the LLM provider:")
    print("1) Ollama/Custom (local or custom API via requests)")
    print("2) OpenAI/ChatGPT (via openai library)")
    print("3) Google Gemini (via google-generativeai library)")
    print("="*60)

    while True:
        choice = input("\nYour choice (1-3): ").strip()

        if choice == "1":
            # Ollama/Custom API
            url = input("Enter the API URL (e.g., http://localhost:11434/api/generate): ").strip()
            model = input("Enter the model name (e.g., llama2, mistral): ").strip()

            return {
                "type": "ollama",
                "url": url,
                "model": model
            }

        elif choice == "2":
            # OpenAI API
            if OpenAI is None:
                print("Error: openai library is not installed.")
                print("Install with: pip install openai")
                continue

            api_key = input("Enter your OpenAI API key: ").strip()
            model = input("Enter the model (e.g., gpt-4, gpt-3.5-turbo) [gpt-3.5-turbo]: ").strip()
            if not model:
                model = "gpt-3.5-turbo"

            client = OpenAI(api_key=api_key)

            return {
                "type": "openai",
                "client": client,
                "model": model
            }

        elif choice == "3":
            # Google Gemini API
            if genai is None:
                print("Error: google-generativeai library is not installed.")
                print("Install with: pip install google-generativeai")
                continue

            api_key = input("Enter your Google API key: ").strip()
            model = input("Enter the model (e.g., gemini-pro, gemini-2.0-flash-live) [gemini-2.0-flash-live]: ").strip()
            if not model:
                model = "gemini-2.0-flash-live"

            genai.configure(api_key=api_key)
            client = genai.GenerativeModel(model)

            return {
                "type": "gemini",
                "client": client,
                "model": model
            }

        else:
            print("Invalid input. Please select 1, 2, or 3.")


# ==================== INCIDENT GENERATION ====================

def generate_user_prompt(num_incidents: int, existing_count: int, config: Optional[Dict[str, Any]] = None) -> str:
    """
    Creates the user prompt for incident generation.

    Args:
        num_incidents: Number of incidents to generate
        existing_count: Number of already existing incidents (for sequential numbering)
        config: Optional configuration with category definitions

    Returns:
        Formatted user prompt as string
    """
    start_number = existing_count + 1
    end_number = existing_count + num_incidents

    # Build category instructions
    category_instructions = ""
    if config and "categories" in config:
        categories = config["categories"]

        if "top_categories" in categories and categories["top_categories"]:
            top_cats = ", ".join([f'"{c}"' for c in categories["top_categories"]])
            category_instructions += f'\n\nIMPORTANT - Use ONLY these Top-Categories: {top_cats}'

        if "sub_categories" in categories and categories["sub_categories"]:
            category_instructions += '\n\nIMPORTANT - Sub-Categories per Top-Category:'
            for top_cat, sub_cats in categories["sub_categories"].items():
                sub_cats_str = ", ".join([f'"{sc}"' for sc in sub_cats])
                category_instructions += f'\n  - {top_cat}: {sub_cats_str}'

        if "specific_categories" in categories and categories["specific_categories"]:
            category_instructions += '\n\nIMPORTANT - Specific Categories per Top-Category:'
            for top_cat, spec_cats in categories["specific_categories"].items():
                spec_cats_str = ", ".join([f'"{sc}"' for sc in spec_cats])
                category_instructions += f'\n  - {top_cat}: {spec_cats_str}'

    prompt = f"""Generate {num_incidents} incident records as a JSON array.

CRITICAL: Use ENGLISH field names EXACTLY as shown below. Do NOT use German or any other language.
CRITICAL: ALL descriptions and text content must be in ENGLISH language.
CRITICAL: ALL incidents MUST have State="Closed" (REQUIRED - NO exceptions){category_instructions}

The "Number" field must be sequential from {start_number} to {end_number}.

Each object in the array must contain EXACTLY these fields with EXACT spelling (in English):
- "Number" (String, e.g., "INC{start_number:06d}")
- "Top-Category" (String, e.g., "Hardware", "Software", "Network")
- "Sub-Category" (String, e.g., "Desktop", "Laptop", "Server")
- "Category" (String, more specific, e.g., "Monitor defect", "Printer offline")
- "Effort" (Number, estimated hours, e.g., 2.5)
- "State" (String, MUST be "Closed" - REQUIRED)
- "Correlation ID" (String, e.g., "CORR-2024-001234")
- "Short Description" (String, max 100 characters, in ENGLISH)
- "Long Description" (String, detailed description, in ENGLISH)
- "Created" (String, ISO format: "YYYY-MM-DD HH:MM:SS")
- "Opened" (String, ISO format, after Created)
- "Closed" (String, ISO format, MUST be filled since State=Closed, after Opened)
- "Priority" (String, one of: "1 - Critical", "2 - High", "3 - Moderate", "4 - Low")
- "Urgency" (String, one of: "1 - High", "2 - Medium", "3 - Low")
- "Impact" (String, one of: "1 - High", "2 - Medium", "3 - Low")
- "Assignment group" (String, e.g., "IT Support Level 1", "Network Team", "Application Support")
- "Resolution code" (String, REQUIRED, e.g., "Solved (Work Around)", "Solved (Permanently)", "Solved (Known Error)")
- "Resolution notes" (String, REQUIRED, detailed explanation of how the incident was resolved, in ENGLISH)
- "Resolve time" (Number, REQUIRED, minutes between Opened and Closed, e.g., 45, 120, 300)
- "Business duration" (Number, business minutes, e.g., 180, 240)
- "Business resolve time" (Number, REQUIRED, business minutes to resolution, e.g., 120, 180)

IMPORTANT: Field names must match EXACTLY including capitalization and spaces.
Example: "Short Description" NOT "Kurzbeschreibung", "Number" NOT "Nummer"

IMPORTANT: Since ALL incidents are CLOSED:
- "Closed" field MUST have a valid date (NOT null)
- "Resolution code" MUST be filled (NOT null)
- "Resolution notes" MUST be filled with a detailed resolution description (NOT null)
- "Resolve time" MUST be filled with minutes (NOT null)
- "Business resolve time" MUST be filled with minutes (NOT null)

Respond ONLY with the JSON array, without additional text, markdown formatting, or code blocks."""

    return prompt


def generate_incident_batch(client_config: Dict[str, Any], num_incidents: int, existing_count: int, config: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """
    Generates a batch of incidents using the selected LLM client.

    Args:
        client_config: Dictionary with client configuration
        num_incidents: Number of incidents to generate
        existing_count: Number of already existing incidents
        config: Optional configuration with category definitions

    Returns:
        List of incident dictionaries
    """
    user_prompt = generate_user_prompt(num_incidents, existing_count, config)
    client_type = client_config["type"]

    with progress_lock:
        print(f"\n→ Generating {num_incidents} incidents (Numbers {existing_count + 1} to {existing_count + num_incidents})...")

    if DEBUG:
        print("\n" + "="*80)
        print("DEBUG: SYSTEM PROMPT")
        print("="*80)
        print(SYSTEM_PROMPT)
        print("\n" + "="*80)
        print("DEBUG: USER PROMPT")
        print("="*80)
        print(user_prompt)
        print("="*80 + "\n")

    try:
        if client_type == "ollama":
            # Ollama/Custom API Request
            response = requests.post(
                client_config["url"],
                json={
                    "model": client_config["model"],
                    "prompt": f"{SYSTEM_PROMPT}\n\n{user_prompt}",
                    "stream": False
                },
                timeout=120
            )
            response.raise_for_status()

            # Depending on Ollama endpoint, response might differ
            data = response.json()
            if "response" in data:
                content = data["response"]
            elif "text" in data:
                content = data["text"]
            else:
                content = str(data)

        elif client_type == "openai":
            # OpenAI API Request
            response = client_config["client"].chat.completions.create(
                model=client_config["model"],
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7
            )
            content = response.choices[0].message.content

        elif client_type == "gemini":
            # Google Gemini API Request
            full_prompt = f"{SYSTEM_PROMPT}\n\n{user_prompt}"
            response = client_config["client"].generate_content(full_prompt)
            content = response.text

        else:
            raise ValueError(f"Unknown client type: {client_type}")

        # Parse JSON Response
        content = content.strip()

        if DEBUG:
            print("\n" + "="*80)
            print("DEBUG: RAW LLM RESPONSE")
            print("="*80)
            print(content)
            print("="*80 + "\n")

        # Remove potential markdown code blocks
        if content.startswith("```"):
            if DEBUG:
                print("DEBUG: Removing markdown code blocks from response")
            lines = content.split("\n")
            lines = [l for l in lines if not l.startswith("```")]
            content = "\n".join(lines).strip()

        # Parse JSON
        if DEBUG:
            print("DEBUG: Parsing JSON response...")
        incidents = json.loads(content)

        if not isinstance(incidents, list):
            raise ValueError("LLM response is not a JSON array")

        if DEBUG:
            print(f"DEBUG: Successfully parsed {len(incidents)} incidents")
            print("DEBUG: First incident sample:")
            if incidents:
                print(json.dumps(incidents[0], indent=2))

        with progress_lock:
            print(f"✓ {len(incidents)} incidents successfully generated (Thread: {threading.current_thread().name})")
        return incidents

    except Exception as e:
        with progress_lock:
            print(f"✗ Error during generation: {str(e)}")
            print(f"Response content (first 500 chars): {content[:500] if 'content' in locals() else 'N/A'}")
        raise


# ==================== MAIN PROGRAM ====================

def load_existing_incidents() -> List[Dict[str, Any]]:
    """
    Loads existing incidents from the temporary JSON file.

    Returns:
        List of incident dictionaries
    """
    if os.path.exists(TEMP_FILE):
        try:
            with open(TEMP_FILE, 'r', encoding='utf-8') as f:
                incidents = json.load(f)
            print(f"\n✓ {len(incidents)} existing incidents loaded from {TEMP_FILE}")
            return incidents
        except Exception as e:
            print(f"\n✗ Error loading {TEMP_FILE}: {e}")
            return []
    return []


def save_incidents_to_temp(incidents: List[Dict[str, Any]]) -> None:
    """
    Saves incidents to the temporary JSON file.

    Args:
        incidents: List of incident dictionaries
    """
    try:
        with open(TEMP_FILE, 'w', encoding='utf-8') as f:
            json.dump(incidents, f, indent=2, ensure_ascii=False)
        print(f"✓ Progress saved to {TEMP_FILE}")
    except Exception as e:
        print(f"✗ Error saving: {e}")


def export_to_xlsx(incidents: List[Dict[str, Any]]) -> None:
    """
    Exports incidents to an XLSX file.

    Args:
        incidents: List of incident dictionaries
    """
    print(f"\n→ Exporting {len(incidents)} incidents to {OUTPUT_FILE}...")

    try:
        # Create DataFrame with exact column names
        df = pd.DataFrame(incidents, columns=COLUMN_NAMES)

        # Export to Excel
        df.to_excel(OUTPUT_FILE, index=False, engine='openpyxl')

        print(f"✓ Export successfully completed: {OUTPUT_FILE}")
        print(f"  Number of records: {len(df)}")
        print(f"  Number of columns: {len(df.columns)}")

    except Exception as e:
        print(f"✗ Error during export: {e}")
        raise


def parse_arguments():
    """
    Parse command line arguments.

    Returns:
        Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description='Generate synthetic incident test data using LLMs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python incident_generator.py                 # Normal mode
  python incident_generator.py --debug         # Debug mode with verbose output
  python incident_generator.py -d              # Debug mode (short flag)

For more information, see README.md
        """
    )
    parser.add_argument(
        '-d', '--debug',
        action='store_true',
        help='Enable debug mode to see API calls and detailed logging'
    )
    return parser.parse_args()


def main():
    """
    Main function of the incident generator.
    """
    # Parse command line arguments
    args = parse_arguments()

    # Set global DEBUG flag
    global DEBUG
    DEBUG = args.debug

    if DEBUG:
        print("\n" + "="*60)
        print("DEBUG MODE ENABLED")
        print("="*60)
        print("Debug output will show:")
        print("  - System and user prompts sent to LLM")
        print("  - Raw API responses")
        print("  - JSON parsing details")
        print("  - Sample generated data")
        print("="*60 + "\n")

    print("\n" + "="*60)
    print("WELCOME TO THE INCIDENT TEST DATA GENERATOR")
    print("="*60)

    # Load configuration
    config = load_config()

    if DEBUG and config:
        print("\nDEBUG: Loaded configuration:")
        # Don't print API keys
        safe_config = {k: v if k not in ['gemini', 'openai'] else '***' for k, v in config.items()}
        print(json.dumps(safe_config, indent=2))

    # Set BATCH_SIZE and NUM_WORKERS from config if available
    global BATCH_SIZE, NUM_WORKERS
    if config and "generation" in config:
        if "batch_size" in config["generation"]:
            BATCH_SIZE = config["generation"]["batch_size"]
            print(f"\n✓ Batch size from configuration: {BATCH_SIZE}")
        if "num_workers" in config["generation"]:
            NUM_WORKERS = config["generation"]["num_workers"]
            print(f"✓ Parallel workers from configuration: {NUM_WORKERS}")

    # Client configuration
    client_config = get_llm_client(config)

    # Number of incidents to generate
    while True:
        try:
            total_incidents = int(input("\nHow many incidents should be generated in total? ").strip())
            if total_incidents > 0:
                break
            print("Please enter a positive number.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    # Load existing incidents
    all_incidents = load_existing_incidents()
    existing_count = len(all_incidents)

    if existing_count >= total_incidents:
        print(f"\n⚠ There are already {existing_count} incidents (target: {total_incidents})")
        overwrite = input("Do you want to start from scratch? (y/n): ").strip().lower()
        if overwrite == 'y':
            all_incidents = []
            existing_count = 0
            if os.path.exists(TEMP_FILE):
                os.remove(TEMP_FILE)
            print("✓ Existing data deleted")
        else:
            print("✓ Proceeding with export")
            export_to_xlsx(all_incidents)
            return

    remaining = total_incidents - existing_count

    print("\n" + "="*60)
    print(f"GENERATION STARTS")
    print(f"Target: {total_incidents} incidents")
    print(f"Already present: {existing_count}")
    print(f"Still to generate: {remaining}")
    print(f"Batch size: {BATCH_SIZE}")
    print(f"Parallel workers: {NUM_WORKERS}")
    print("="*60)

    # Generation loop with parallel execution
    try:
        with ThreadPoolExecutor(max_workers=NUM_WORKERS) as executor:
            while len(all_incidents) < total_incidents:
                # Calculate how many batches we can submit in parallel
                remaining = total_incidents - len(all_incidents)

                # Submit multiple batch jobs
                futures = []
                for i in range(min(NUM_WORKERS, (remaining + BATCH_SIZE - 1) // BATCH_SIZE)):
                    if len(all_incidents) + (i * BATCH_SIZE) >= total_incidents:
                        break

                    current_batch_size = min(BATCH_SIZE, total_incidents - len(all_incidents) - (i * BATCH_SIZE))
                    if current_batch_size <= 0:
                        break

                    # Calculate starting count for this batch
                    batch_start_count = len(all_incidents) + (i * BATCH_SIZE)

                    # Submit batch generation to thread pool
                    future = executor.submit(
                        generate_incident_batch,
                        client_config,
                        current_batch_size,
                        batch_start_count,
                        config
                    )
                    futures.append(future)

                # Collect results as they complete
                for future in as_completed(futures):
                    try:
                        batch = future.result()
                        all_incidents.extend(batch)

                        # Save intermediate results (thread-safe)
                        with progress_lock:
                            save_incidents_to_temp(all_incidents)
                            print(f"  Progress: {len(all_incidents)}/{total_incidents} incidents")

                    except Exception as e:
                        with progress_lock:
                            print(f"✗ Batch generation failed: {str(e)}")
                        # Continue with other batches

        print("\n" + "="*60)
        print("✓ GENERATION COMPLETED")
        print("="*60)

        # Export to XLSX
        export_to_xlsx(all_incidents)

        # Cleanup
        cleanup = input(f"\nDo you want to delete the temporary file {TEMP_FILE}? (y/n): ").strip().lower()
        if cleanup == 'y':
            if os.path.exists(TEMP_FILE):
                os.remove(TEMP_FILE)
                print(f"✓ {TEMP_FILE} has been deleted")

        print("\n" + "="*60)
        print("DONE!")
        print("="*60)

    except KeyboardInterrupt:
        print("\n\n⚠ Generation aborted by user")
        print(f"Progress has been saved to {TEMP_FILE}")
        print(f"Generated so far: {len(all_incidents)} incidents")

    except Exception as e:
        print(f"\n✗ ERROR: {str(e)}")
        print(f"Progress has been saved to {TEMP_FILE}")
        print(f"Generated so far: {len(all_incidents)} incidents")
        raise


if __name__ == "__main__":
    main()
