@echo off
REM GPU Load Test Script for Windows
setlocal enabledelayedexpansion

echo ============================================
echo === GPU Load Test fuer Ollama (Windows) ===
echo ============================================
echo.

REM Check if nvidia-smi is available
where nvidia-smi >nul 2>&1
if %errorlevel% neq 0 (
    echo FEHLER: nvidia-smi nicht gefunden!
    echo Bitte stellen Sie sicher, dass NVIDIA-Treiber installiert sind.
    pause
    exit /b 1
)

REM Check if curl is available
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo FEHLER: curl nicht gefunden!
    echo Bitte installieren Sie curl oder verwenden Sie Windows 10/11.
    pause
    exit /b 1
)

echo 1. Aktuelle GPU-Auslastung:
echo -------------------------------------------
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv
echo.

echo 2. Ollama Environment-Variablen:
echo -------------------------------------------
set | findstr /I "OLLAMA"
if %errorlevel% neq 0 (
    echo Keine OLLAMA-Umgebungsvariablen gesetzt.
    echo.
    echo Empfehlung: Setzen Sie diese Variablen vor dem Starten von Ollama:
    echo   set OLLAMA_NUM_PARALLEL=4
    echo   set OLLAMA_MAX_LOADED_MODELS=1
    echo   set OLLAMA_KEEP_ALIVE=10m
)
echo.

echo 3. Test: Einzelne Anfrage
echo -------------------------------------------
echo Starte einzelne Test-Anfrage...
echo (Erwartete GPU-Auslastung: ~15-30%%)

REM Create temporary JSON file
echo {"model": "llama3.1:8b", "prompt": "Generate 5 short incident descriptions for IT problems", "stream": false} > temp_request.json

REM Start single request in background
start /B "" curl -s http://localhost:11434/api/generate -d @temp_request.json -o nul

REM Wait and check GPU
timeout /t 3 /nobreak >nul
echo GPU-Auslastung waehrend Single Request:
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
echo.

REM Wait for request to complete
timeout /t 5 /nobreak >nul

echo 4. Test: 4 parallele Anfragen
echo -------------------------------------------
echo Starte 4 parallele Test-Anfragen...
echo (Erwartete GPU-Auslastung: ^>50%% bei optimaler Konfiguration)

REM Start 4 parallel requests
start /B "" curl -s http://localhost:11434/api/generate -d @temp_request.json -o nul
start /B "" curl -s http://localhost:11434/api/generate -d @temp_request.json -o nul
start /B "" curl -s http://localhost:11434/api/generate -d @temp_request.json -o nul
start /B "" curl -s http://localhost:11434/api/generate -d @temp_request.json -o nul

REM Wait and check GPU
timeout /t 4 /nobreak >nul
echo GPU-Auslastung waehrend 4 parallelen Requests:
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
echo.

REM Cleanup
del temp_request.json 2>nul

REM Wait for all requests to complete
echo Warte auf Abschluss aller Requests...
timeout /t 10 /nobreak >nul

echo 5. Test abgeschlossen!
echo ============================================
echo.

echo 6. GPU-Information und Empfehlungen:
echo -------------------------------------------
for /f "tokens=1,2 delims=," %%a in ('nvidia-smi --query-gpu=name^,memory.total --format=csv^,noheader') do (
    set GPU_NAME=%%a
    set GPU_MEM=%%b
    echo GPU: !GPU_NAME!
    echo VRAM: !GPU_MEM!
    echo.

    REM Extract memory size in GB
    set MEM_STR=!GPU_MEM!
    for /f "tokens=1" %%m in ("!MEM_STR!") do set MEM_GB=%%m

    echo Empfohlene Einstellungen:
    if !MEM_GB! GTR 20000 (
        echo   - GPU hat viel VRAM ^(^>20GB^)
        echo   - Kann grosse Modelle oder hohe Parallelitaet nutzen
        echo   - Empfohlen in config.json:
        echo       "num_workers": 5,
        echo       "batch_size": 10
        echo.
        echo   - Optional: Groesseres Modell testen
        echo       ollama pull llama3.1:70b
    ) else if !MEM_GB! GTR 12000 (
        echo   - GPU hat mittleres VRAM ^(12-20GB^)
        echo   - Gut fuer llama3.1:8b mit Parallelitaet
        echo   - Empfohlen in config.json:
        echo       "num_workers": 4,
        echo       "batch_size": 8
        echo.
        echo   - Ollama mit mehr Parallelitaet starten:
        echo       set OLLAMA_NUM_PARALLEL=4
        echo       ollama serve
    ) else (
        echo   - GPU hat begrenztes VRAM ^(^<12GB^)
        echo   - Empfohlen in config.json:
        echo       "num_workers": 2,
        echo       "batch_size": 5
        echo.
        echo   - Kleineres Modell kann schneller sein:
        echo       ollama pull llama3.2:3b
    )
)

echo.
echo ============================================
echo HINWEIS: Niedrige GPU-Auslastung ^(15-20%%^) kann normal sein!
echo.
echo Bei modernen Modellen ^(llama3.1:8b^) mit Flash Attention sind die
echo Inferenz-Operationen sehr effizient. Wichtiger als GPU-Auslastung
echo ist die tatsaechliche Geschwindigkeit ^(Tokens/Sekunde^).
echo.
echo Wenn Ihre Generierung schnell ist ^(^<1 Minute pro Batch^), ist
echo Ihre Konfiguration bereits optimal!
echo ============================================
echo.

pause
