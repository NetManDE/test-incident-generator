@echo off
REM setup.bat - Creates Python Virtual Environment and installs dependencies (Windows)

echo ======================================
echo INCIDENT GENERATOR - SETUP
echo ======================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed
    echo   Please install Python 3.7+ from https://www.python.org/downloads/
    echo   Make sure to check "Add Python to PATH" during installation
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo [OK] Python found: %PYTHON_VERSION%
echo.

REM Virtual Environment directory
set VENV_DIR=venv

REM Check if venv already exists
if exist "%VENV_DIR%" (
    echo [WARNING] Virtual Environment '%VENV_DIR%' already exists
    set /p RECREATE="Do you want to recreate it? (y/n): "
    if /i "%RECREATE%"=="y" (
        echo [INFO] Deleting existing venv...
        rmdir /s /q "%VENV_DIR%"
    ) else (
        echo [OK] Using existing venv
        echo.
    )
)

REM Create Virtual Environment
if not exist "%VENV_DIR%" (
    echo [INFO] Creating Virtual Environment...
    python -m venv "%VENV_DIR%"

    if errorlevel 1 (
        echo [ERROR] Error creating Virtual Environment
        echo   Make sure Python venv module is available
        pause
        exit /b 1
    )

    echo [OK] Virtual Environment successfully created
)

echo.

REM Activate Virtual Environment
echo [INFO] Activating Virtual Environment...
call "%VENV_DIR%\Scripts\activate.bat"

if errorlevel 1 (
    echo [ERROR] Error activating Virtual Environment
    pause
    exit /b 1
)

echo [OK] Virtual Environment activated
echo.

REM Upgrade pip
echo [INFO] Updating pip...
python -m pip install --upgrade pip >nul 2>&1

if errorlevel 1 (
    echo [WARNING] pip could not be updated (not critical)
) else (
    echo [OK] pip successfully updated
)

echo.

REM Install dependencies
echo [INFO] Installing Python libraries...
echo   - pandas
echo   - openpyxl
echo   - requests
echo   - openai
echo   - google-generativeai
echo.

pip install pandas openpyxl requests openai google-generativeai

if errorlevel 1 (
    echo.
    echo [ERROR] Error installing libraries
    pause
    exit /b 1
)

echo.

REM Create configuration file
set CONFIG_FILE=config.json
set CONFIG_EXAMPLE=config.json.example

echo ======================================
echo CONFIGURATION
echo ======================================
echo.

if exist "%CONFIG_FILE%" (
    echo [OK] Configuration file already exists: %CONFIG_FILE%
    echo.
    set /p EDIT="Do you want to edit/overwrite it? (y/n): "
    if /i "%EDIT%"=="y" (
        copy /y "%CONFIG_EXAMPLE%" "%CONFIG_FILE%" >nul
        echo [OK] config.json was copied from config.json.example
        echo.
        echo [IMPORTANT] Please edit %CONFIG_FILE% now and add your API key!
        echo.
    )
) else (
    echo [INFO] Creating configuration file from template...
    if exist "%CONFIG_EXAMPLE%" (
        copy "%CONFIG_EXAMPLE%" "%CONFIG_FILE%" >nul
        echo [OK] %CONFIG_FILE% has been created
        echo.
        echo [IMPORTANT] Please edit %CONFIG_FILE% now and add the following information:
        echo   1. Choose your LLM provider (llm_provider: 'ollama', 'openai' or 'gemini')
        echo   2. Add the corresponding API key
        echo   3. Optional: Adjust the model and batch size
        echo.
        echo Example for Gemini (recommended for fast generation):
        echo   "llm_provider": "gemini"
        echo   "gemini": {
        echo     "api_key": "YOUR_GOOGLE_API_KEY",
        echo     "model": "gemini-2.0-flash-live"
        echo   }
        echo.
    ) else (
        echo [WARNING] %CONFIG_EXAMPLE% not found
        echo   You can still run the script, but will be asked interactively for data
        echo.
    )
)

echo.
echo ======================================
echo [OK] SETUP SUCCESSFULLY COMPLETED
echo ======================================
echo.
echo Next steps:
echo   1. If not done yet: Edit config.json and add your API key
echo   2. Run 'run.bat' to start the generator
echo   3. Or activate the venv manually: venv\Scripts\activate.bat
echo.
pause
