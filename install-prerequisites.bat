@echo off
REM install-prerequisites.bat - Downloads and installs Python and Ollama (Windows)

echo ======================================
echo PREREQUISITES INSTALLER
echo ======================================
echo.
echo This script will help you install:
echo   1. Python 3.12 (if not already installed)
echo   2. Ollama (optional, for local LLM usage)
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

REM ==================== CHECK PYTHON ====================

echo ======================================
echo CHECKING PYTHON
echo ======================================
echo.

python --version >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Python is not installed
    echo.
    set /p INSTALL_PYTHON="Do you want to install Python 3.12? (y/n): "

    if /i "%INSTALL_PYTHON%"=="y" (
        echo.
        echo [INFO] Downloading Python 3.12 installer...
        echo.

        REM Download Python installer
        set PYTHON_INSTALLER=python-3.12-installer.exe
        set PYTHON_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe

        powershell -Command "& {Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%'}"

        if errorlevel 1 (
            echo [ERROR] Failed to download Python installer
            echo.
            echo Please download manually from: https://www.python.org/downloads/
            echo Make sure to check 'Add Python to PATH' during installation
            pause
            exit /b 1
        )

        echo [OK] Python installer downloaded
        echo.
        echo [INFO] Starting Python installation...
        echo.
        echo IMPORTANT: Please check "Add Python to PATH" during installation!
        echo.
        pause

        REM Install Python silently with PATH option
        start /wait %PYTHON_INSTALLER% /passive PrependPath=1 Include_test=0

        echo.
        echo [OK] Python installation completed
        echo.
        echo Cleaning up...
        del "%PYTHON_INSTALLER%"

        echo.
        echo [INFO] Refreshing environment variables...
        echo Please close and reopen this terminal window, then run this script again.
        echo.
        pause
        exit /b 0
    ) else (
        echo.
        echo [INFO] Skipping Python installation
        echo.
        echo Please install Python manually from: https://www.python.org/downloads/
        echo Make sure to check 'Add Python to PATH' during installation
        echo.
    )
) else (
    for /f "tokens=*" %%i in ('python --version') do set PYTHON_VERSION=%%i
    echo [OK] Python is already installed: %PYTHON_VERSION%
)

echo.

REM ==================== CHECK OLLAMA ====================

echo ======================================
echo CHECKING OLLAMA
echo ======================================
echo.

ollama --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] Ollama is not installed
    echo.
    echo Ollama is optional and only needed if you want to use local LLM models.
    echo You can also use OpenAI or Google Gemini instead.
    echo.
    set /p INSTALL_OLLAMA="Do you want to install Ollama? (y/n): "

    if /i "%INSTALL_OLLAMA%"=="y" (
        echo.
        echo [INFO] Downloading Ollama installer...
        echo.

        REM Download Ollama installer
        set OLLAMA_INSTALLER=OllamaSetup.exe
        set OLLAMA_URL=https://ollama.com/download/OllamaSetup.exe

        powershell -Command "& {Invoke-WebRequest -Uri '%OLLAMA_URL%' -OutFile '%OLLAMA_INSTALLER%'}"

        if errorlevel 1 (
            echo [ERROR] Failed to download Ollama installer
            echo.
            echo Please download manually from: https://ollama.com/download
            pause
            exit /b 1
        )

        echo [OK] Ollama installer downloaded
        echo.
        echo [INFO] Starting Ollama installation...
        echo.
        pause

        REM Install Ollama
        start /wait %OLLAMA_INSTALLER%

        echo.
        echo [OK] Ollama installation completed
        echo.
        echo Cleaning up...
        del "%OLLAMA_INSTALLER%"

        echo.
        echo [INFO] After installation, you can download LLM models with:
        echo   ollama pull llama2
        echo   ollama pull mistral
        echo.
    ) else (
        echo.
        echo [INFO] Skipping Ollama installation
        echo.
        echo You can install it later from: https://ollama.com/download
        echo.
    )
) else (
    for /f "tokens=*" %%i in ('ollama --version') do set OLLAMA_VERSION=%%i
    echo [OK] Ollama is already installed: %OLLAMA_VERSION%
    echo.
    echo [INFO] You can download LLM models with:
    echo   ollama pull llama2
    echo   ollama pull mistral
    echo.
)

echo.
echo ======================================
echo INSTALLATION SUMMARY
echo ======================================
echo.

REM Check final status
python --version >nul 2>&1
if errorlevel 1 (
    echo [X] Python: Not installed
) else (
    for /f "tokens=*" %%i in ('python --version') do echo [OK] Python: %%i
)

ollama --version >nul 2>&1
if errorlevel 1 (
    echo [X] Ollama: Not installed (optional)
) else (
    for /f "tokens=*" %%i in ('ollama --version') do echo [OK] Ollama: %%i
)

echo.
echo ======================================
echo NEXT STEPS
echo ======================================
echo.
echo 1. If you just installed Python, close and reopen your terminal
echo 2. Run 'setup.bat' to create the Python environment
echo 3. Edit 'config.json' to add your API key
echo 4. Run 'run.bat' to start the generator
echo.
echo For Gemini API (recommended):
echo   - Get free API key: https://makersuite.google.com/app/apikey
echo   - Model: gemini-2.0-flash-live (no rate limit)
echo.
echo For OpenAI API:
echo   - Get API key: https://platform.openai.com/api-keys
echo   - Model: gpt-3.5-turbo or gpt-4
echo.
echo For Ollama (local):
echo   - Download models: ollama pull llama2
echo   - URL: http://localhost:11434/api/generate
echo.
pause
