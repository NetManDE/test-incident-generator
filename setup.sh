#!/bin/bash

# setup.sh - Creates Python Virtual Environment and installs dependencies

echo "======================================"
echo "INCIDENT GENERATOR - SETUP"
echo "======================================"
echo ""

# Check if Python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "✗ Error: python3 is not installed"
    echo "  Please install Python 3 and try again"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo "✓ Python found: $PYTHON_VERSION"
echo ""

# Virtual Environment directory
VENV_DIR="venv"

# Check if venv already exists
if [ -d "$VENV_DIR" ]; then
    echo "⚠ Virtual Environment '$VENV_DIR' already exists"
    read -p "Do you want to recreate it? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "→ Deleting existing venv..."
        rm -rf "$VENV_DIR"
    else
        echo "✓ Using existing venv"
        echo ""
    fi
fi

# Create Virtual Environment
if [ ! -d "$VENV_DIR" ]; then
    echo "→ Creating Virtual Environment..."
    python3 -m venv "$VENV_DIR"

    if [ $? -ne 0 ]; then
        echo "✗ Error creating Virtual Environment"
        echo "  python3-venv might be missing"
        echo "  Installation: sudo apt install python3-venv (Debian/Ubuntu)"
        exit 1
    fi

    echo "✓ Virtual Environment successfully created"
fi

echo ""

# Activate Virtual Environment
echo "→ Activating Virtual Environment..."
source "$VENV_DIR/bin/activate"

if [ $? -ne 0 ]; then
    echo "✗ Error activating Virtual Environment"
    exit 1
fi

echo "✓ Virtual Environment activated"
echo ""

# Upgrade pip
echo "→ Updating pip..."
pip install --upgrade pip > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ pip successfully updated"
else
    echo "⚠ pip could not be updated (not critical)"
fi

echo ""

# Install dependencies
echo "→ Installing Python libraries..."
echo "  - pandas"
echo "  - openpyxl"
echo "  - requests"
echo "  - openai"
echo "  - google-generativeai"
echo ""

pip install pandas openpyxl requests openai google-generativeai

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Error installing libraries"
    exit 1
fi

echo ""

# Create configuration file
CONFIG_FILE="config.json"
CONFIG_EXAMPLE="config.json.example"

echo "======================================"
echo "CONFIGURATION"
echo "======================================"
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "✓ Configuration file already exists: $CONFIG_FILE"
    echo ""
    read -p "Do you want to edit/overwrite it? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
        echo "✓ config.json was copied from config.json.example"
        echo ""
        echo "⚠ IMPORTANT: Please edit $CONFIG_FILE now and add your API key!"
        echo ""
    fi
else
    echo "→ Creating configuration file from template..."
    if [ -f "$CONFIG_EXAMPLE" ]; then
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
        echo "✓ $CONFIG_FILE has been created"
        echo ""
        echo "⚠ IMPORTANT: Please edit $CONFIG_FILE now and add the following information:"
        echo "  1. Choose your LLM provider (llm_provider: 'ollama', 'openai' or 'gemini')"
        echo "  2. Add the corresponding API key"
        echo "  3. Optional: Adjust the model and batch size"
        echo ""
        echo "Example for Gemini (recommended for fast generation):"
        echo "  \"llm_provider\": \"gemini\""
        echo "  \"gemini\": {"
        echo "    \"api_key\": \"YOUR_GOOGLE_API_KEY\","
        echo "    \"model\": \"gemini-2.0-flash-live\""
        echo "  }"
        echo ""
    else
        echo "⚠ Warning: $CONFIG_EXAMPLE not found"
        echo "  You can still run the script, but will be asked interactively for data"
        echo ""
    fi
fi

echo ""
echo "======================================"
echo "✓ SETUP SUCCESSFULLY COMPLETED"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. If not done yet: Edit config.json and add your API key"
echo "  2. Run './run.sh' to start the generator"
echo "  3. Or activate the venv manually: source venv/bin/activate"
echo ""
