# Incident Test Data Generator

Generates synthetic IT incident test data using LLMs (Large Language Models) and exports them to an Excel file.

## Features

- **Flexible LLM Support**: Ollama/Custom, OpenAI/ChatGPT, Google Gemini
- **21 Realistic Data Columns**: Number, Categories, Status, Timestamps, Priorities, etc.
- **Configuration File**: Stores API keys and settings
- **Intermediate Caching**: Automatic backup after each batch
- **Batch Processing**: Generates multiple incidents per API request
- **Excel Export**: XLSX format with English column headers

## Quick Start

### 1. One-Time Setup

```bash
./setup.sh
```

This creates:
- Python Virtual Environment
- Installs all dependencies
- Creates `config.json` from `config.json.example`

### 2. Configuration

Edit `config.json` and add your API key:

```json
{
  "llm_provider": "gemini",

  "gemini": {
    "api_key": "YOUR_GOOGLE_API_KEY",
    "model": "gemini-2.0-flash-live"
  },

  "generation": {
    "batch_size": 5
  }
}
```

**Recommendation**: Use `gemini-2.0-flash-live` for fast generation without rate limits!

### 3. Start Generator

```bash
./run.sh
```

## Supported LLM Providers

### Google Gemini (Recommended)

```json
{
  "llm_provider": "gemini",
  "gemini": {
    "api_key": "YOUR_API_KEY",
    "model": "gemini-2.0-flash-live"
  }
}
```

**Benefits**:
- `gemini-2.0-flash-live`: No rate limit
- Fast generation
- Available for free

Get API key: https://makersuite.google.com/app/apikey

### OpenAI/ChatGPT

```json
{
  "llm_provider": "openai",
  "openai": {
    "api_key": "YOUR_API_KEY",
    "model": "gpt-3.5-turbo"
  }
}
```

Models: `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`

### Ollama (Local)

```json
{
  "llm_provider": "ollama",
  "ollama": {
    "url": "http://localhost:11434/api/generate",
    "model": "llama2"
  }
}
```

Requires local Ollama installation: https://ollama.ai/

## Generated Data Structure

The script generates incidents with 21 columns:

| Column | Description | Example |
|--------|-------------|---------|
| Number | Sequential ID | INC000001 |
| Top-Category | Main category | Hardware, Software, Network |
| Sub-Category | Subcategory | Desktop, Laptop, Server |
| Category | Specific category | Monitor defect, Printer offline |
| Effort | Estimated hours | 2.5 |
| State | Status | New, In Progress, Resolved, Closed |
| Correlation ID | Correlation ID | CORR-2024-001234 |
| Short Description | Brief description | Printer not printing |
| Long Description | Detailed description | User cannot print... |
| Created | Creation date | 2024-01-15 09:30:00 |
| Opened | Opening date | 2024-01-15 09:35:00 |
| Closed | Closing date | 2024-01-15 14:20:00 |
| Priority | Priority | 1 - Critical, 2 - High, 3 - Moderate, 4 - Low |
| Urgency | Urgency | 1 - High, 2 - Medium, 3 - Low |
| Impact | Impact | 1 - High, 2 - Medium, 3 - Low |
| Assignment group | Assignment group | IT Support Level 1, Network Team |
| Resolution code | Resolution code | Solved (Permanently) |
| Resolution notes | Resolution notes | Problem solved by reboot |
| Resolve time | Resolution time (min) | 290 |
| Business duration | Business duration (min) | 240 |
| Business resolve time | Business resolution time (min) | 240 |

## Configuration Options

### Adjust Batch Size

```json
{
  "generation": {
    "batch_size": 10
  }
}
```

- Smaller values (1-5): More stable, but slower
- Larger values (10-20): Faster, but potentially more error-prone

### Configure Categories

You can customize the incident categories in `config.json`:

```json
{
  "categories": {
    "top_categories": ["Hardware", "Software", "Network", "Security", "Access Management"],
    "sub_categories": {
      "Hardware": ["Desktop", "Laptop", "Server", "Printer", "Monitor"],
      "Software": ["Application", "Operating System", "Database", "Email"],
      "Network": ["Router", "Switch", "Firewall", "VPN", "WiFi"]
    },
    "specific_categories": {
      "Hardware": ["Device not working", "Device overheating", "Hardware failure"],
      "Software": ["Application crash", "Software not responding", "Installation failed"],
      "Network": ["No network connection", "Slow connection", "VPN connection failed"]
    }
  }
}
```

**Benefits**:
- Control which categories appear in your test data
- Align with your organization's incident categories
- Ensure consistent categorization across all generated incidents
- Leave empty or omit to let the LLM generate categories freely

### Without Configuration File

If no `config.json` is present, the script will ask interactively for all necessary information.

## Output Files

- **`incidents_export.xlsx`**: Final Excel file with all incidents
- **`temp_incidents.json`**: Temporary intermediate storage (automatic backup)

## Advanced Usage

### Resume Generation

If generation is interrupted:

```bash
./run.sh
```

The script automatically loads `temp_incidents.json` and resumes generation.

### Manually Activate venv

```bash
source venv/bin/activate
python3 incident_generator.py
```

### Change Batch Size at Runtime

Edit `config.json` and restart `./run.sh`.

## Dependencies

- Python 3.7+
- pandas
- openpyxl
- requests
- openai (optional)
- google-generativeai (optional)

## Security Notes

- **NEVER** commit `config.json` to Git (contains API keys!)
- The `.gitignore` automatically protects against accidental commits
- `config.json.example` can be safely shared (contains no secrets)

## Troubleshooting

### "openai library is not installed"

```bash
source venv/bin/activate
pip install openai
```

### "google-generativeai library is not installed"

```bash
source venv/bin/activate
pip install google-generativeai
```

### JSON Parse Error

The LLM returned invalid JSON. Possible solutions:
- Use a more reliable model (e.g., `gemini-2.0-flash-live`)
- Reduce the batch size
- Try again (sometimes a temporary issue)

### Rate Limit Exceeded (OpenAI)

- Use smaller batch sizes
- Add pauses between batches
- Switch to `gemini-2.0-flash-live` (no rate limit)

## Performance Tips

**Fastest Configuration**:

```json
{
  "llm_provider": "gemini",
  "gemini": {
    "api_key": "YOUR_API_KEY",
    "model": "gemini-2.0-flash-live"
  },
  "generation": {
    "batch_size": 10
  }
}
```

With this configuration, you can generate 100+ incidents in just a few minutes!

## License

Free to use for testing purposes.
