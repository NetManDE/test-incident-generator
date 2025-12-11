@echo off
REM run.bat - Activates Virtual Environment and starts the Incident Generator (Windows)

set VENV_DIR=venv
set PYTHON_SCRIPT=incident_generator.py

REM Check if Virtual Environment exists
if not exist "%VENV_DIR%" (
    echo [ERROR] Virtual Environment '%VENV_DIR%' not found
    echo.
    echo Please run the setup first:
    echo   setup.bat
    echo.
    pause
    exit /b 1
)

REM Check if Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo [ERROR] Python script '%PYTHON_SCRIPT%' not found
    pause
    exit /b 1
)

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

REM Start Python script
python "%PYTHON_SCRIPT%"

REM Save exit code
set EXIT_CODE=%errorlevel%

REM Deactivate Virtual Environment
call deactivate

REM Exit with the Python script's exit code
exit /b %EXIT_CODE%
