# GPU Load Test Script for Windows (PowerShell)
# Testet die GPU-Auslastung bei Ollama mit parallelen Anfragen

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "=== GPU Load Test fuer Ollama (Windows) ===" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Check if nvidia-smi is available
try {
    $null = Get-Command nvidia-smi -ErrorAction Stop
} catch {
    Write-Host "FEHLER: nvidia-smi nicht gefunden!" -ForegroundColor Red
    Write-Host "Bitte stellen Sie sicher, dass NVIDIA-Treiber installiert sind." -ForegroundColor Yellow
    Read-Host "Druecken Sie Enter zum Beenden"
    exit 1
}

# 1. GPU Information
Write-Host "1. Aktuelle GPU-Auslastung:" -ForegroundColor Green
Write-Host "-------------------------------------------"
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv
Write-Host ""

# 2. Ollama Environment
Write-Host "2. Ollama Environment-Variablen:" -ForegroundColor Green
Write-Host "-------------------------------------------"
$ollamaVars = Get-ChildItem Env: | Where-Object { $_.Name -like "OLLAMA*" }
if ($ollamaVars.Count -eq 0) {
    Write-Host "Keine OLLAMA-Umgebungsvariablen gesetzt." -ForegroundColor Yellow
    Write-Host "`nEmpfehlung: Setzen Sie diese Variablen vor dem Starten von Ollama:" -ForegroundColor Yellow
    Write-Host '  $env:OLLAMA_NUM_PARALLEL=4' -ForegroundColor Cyan
    Write-Host '  $env:OLLAMA_MAX_LOADED_MODELS=1' -ForegroundColor Cyan
    Write-Host '  $env:OLLAMA_KEEP_ALIVE="10m"' -ForegroundColor Cyan
} else {
    $ollamaVars | ForEach-Object {
        Write-Host "  $($_.Name) = $($_.Value)"
    }
}
Write-Host ""

# 3. Single Request Test
Write-Host "3. Test: Einzelne Anfrage" -ForegroundColor Green
Write-Host "-------------------------------------------"
Write-Host "Starte einzelne Test-Anfrage..."
Write-Host "(Erwartete GPU-Auslastung: ~15-30%)" -ForegroundColor Yellow

$requestBody = @{
    model = "llama3.1:8b"
    prompt = "Generate 5 short incident descriptions for IT problems"
    stream = $false
} | ConvertTo-Json

# Start single request
$job1 = Start-Job -ScriptBlock {
    param($body)
    try {
        Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {
        # Ignore errors for this test
    }
} -ArgumentList $requestBody

Start-Sleep -Seconds 3
Write-Host "GPU-Auslastung waehrend Single Request:"
$gpuUtil = nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
Write-Host "  $gpuUtil" -ForegroundColor Cyan
Write-Host ""

# Wait for completion
Wait-Job $job1 -Timeout 30 | Out-Null
Remove-Job $job1 -Force

# 4. Parallel Request Test
Write-Host "4. Test: 4 parallele Anfragen" -ForegroundColor Green
Write-Host "-------------------------------------------"
Write-Host "Starte 4 parallele Test-Anfragen..."
Write-Host "(Erwartete GPU-Auslastung: >50% bei optimaler Konfiguration)" -ForegroundColor Yellow

# Start 4 parallel requests
$jobs = 1..4 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($body)
        try {
            Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json" | Out-Null
        } catch {
            # Ignore errors for this test
        }
    } -ArgumentList $requestBody
}

Start-Sleep -Seconds 4
Write-Host "GPU-Auslastung waehrend 4 parallelen Requests:"
$gpuUtilParallel = nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
Write-Host "  $gpuUtilParallel" -ForegroundColor Cyan
Write-Host ""

# Wait for completion
Write-Host "Warte auf Abschluss aller Requests..." -ForegroundColor Yellow
Wait-Job $jobs -Timeout 60 | Out-Null
Remove-Job $jobs -Force

Write-Host "5. Test abgeschlossen!" -ForegroundColor Green
Write-Host "============================================`n"

# 6. Recommendations
Write-Host "6. GPU-Information und Empfehlungen:" -ForegroundColor Green
Write-Host "-------------------------------------------"

$gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
$gpuName, $gpuMemStr = $gpuInfo -split ','
$gpuMemGB = [int]($gpuMemStr.Trim() -replace '[^\d]', '') / 1024

Write-Host "GPU: $($gpuName.Trim())"
Write-Host "VRAM: $($gpuMemStr.Trim())"
Write-Host ""

Write-Host "Empfohlene Einstellungen:" -ForegroundColor Yellow
if ($gpuMemGB -gt 20) {
    Write-Host "  - GPU hat viel VRAM (>20GB)" -ForegroundColor Green
    Write-Host "  - Kann grosse Modelle oder hohe Parallelitaet nutzen"
    Write-Host "  - Empfohlen in config.json:"
    Write-Host '      "num_workers": 5,' -ForegroundColor Cyan
    Write-Host '      "batch_size": 10' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  - Optional: Groesseres Modell testen"
    Write-Host "      ollama pull llama3.1:70b" -ForegroundColor Cyan
} elseif ($gpuMemGB -gt 12) {
    Write-Host "  - GPU hat mittleres VRAM (12-20GB)" -ForegroundColor Green
    Write-Host "  - Gut fuer llama3.1:8b mit Parallelitaet"
    Write-Host "  - Empfohlen in config.json:"
    Write-Host '      "num_workers": 4,' -ForegroundColor Cyan
    Write-Host '      "batch_size": 8' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  - Ollama mit mehr Parallelitaet starten:"
    Write-Host '      $env:OLLAMA_NUM_PARALLEL=4' -ForegroundColor Cyan
    Write-Host '      ollama serve' -ForegroundColor Cyan
} else {
    Write-Host "  - GPU hat begrenztes VRAM (<12GB)" -ForegroundColor Yellow
    Write-Host "  - Empfohlen in config.json:"
    Write-Host '      "num_workers": 2,' -ForegroundColor Cyan
    Write-Host '      "batch_size": 5' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  - Kleineres Modell kann schneller sein:"
    Write-Host "      ollama pull llama3.2:3b" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "HINWEIS: Niedrige GPU-Auslastung (15-20%) kann normal sein!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Bei modernen Modellen (llama3.1:8b) mit Flash Attention sind die"
Write-Host "Inferenz-Operationen sehr effizient. Wichtiger als GPU-Auslastung"
Write-Host "ist die tatsaechliche Geschwindigkeit (Tokens/Sekunde)."
Write-Host ""
Write-Host "Wenn Ihre Generierung schnell ist (<1 Minute pro Batch), ist"
Write-Host "Ihre Konfiguration bereits optimal!"
Write-Host "============================================`n" -ForegroundColor Cyan

Read-Host "Druecken Sie Enter zum Beenden"
