#!/bin/bash

# run.sh - Activates Virtual Environment and starts the Incident Generator
# Usage: ./run.sh [--debug]

VENV_DIR="venv"
PYTHON_SCRIPT="incident_generator.py"

# Parse command line arguments
DEBUG_FLAG=""
if [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    DEBUG_FLAG="--debug"
    echo "Debug mode enabled"
fi

# Check if Virtual Environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "✗ Error: Virtual Environment '$VENV_DIR' not found"
    echo ""
    echo "Please run the setup first:"
    echo "  ./setup.sh"
    echo ""
    exit 1
fi

# Check if Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "✗ Error: Python script '$PYTHON_SCRIPT' not found"
    exit 1
fi

# Activate Virtual Environment
echo "→ Activating Virtual Environment..."
source "$VENV_DIR/bin/activate"

if [ $? -ne 0 ]; then
    echo "✗ Error activating Virtual Environment"
    exit 1
fi

echo "✓ Virtual Environment activated"
echo ""

# Start Python script
python3 "$PYTHON_SCRIPT" $DEBUG_FLAG

# Save exit code
EXIT_CODE=$?

# Deactivate Virtual Environment
deactivate

# Exit with the Python script's exit code
exit $EXIT_CODE
