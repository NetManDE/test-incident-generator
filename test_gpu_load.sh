#!/bin/bash
# GPU Load Test Script

echo "=== GPU Load Test für Ollama ==="
echo ""

# Zeige aktuelle GPU-Info
echo "1. Aktuelle GPU-Auslastung:"
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total --format=csv
echo ""

# Zeige Ollama-Konfiguration
echo "2. Ollama Environment:"
env | grep OLLAMA
echo ""

# Test einzelne Anfrage
echo "3. Test: Einzelne Anfrage (sollte ~15-30% GPU nutzen)..."
time curl -s http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Generate 5 short incident descriptions for IT problems",
  "stream": false
}' > /dev/null &

sleep 2
echo "GPU während Single Request:"
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
wait

echo ""
echo "4. Test: 4 parallele Anfragen (sollte >50% GPU nutzen)..."
for i in {1..4}; do
  curl -s http://localhost:11434/api/generate -d '{
    "model": "llama3.1:8b",
    "prompt": "Generate 5 short incident descriptions for IT problems",
    "stream": false
  }' > /dev/null &
done

sleep 3
echo "GPU während 4 parallelen Requests:"
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
wait

echo ""
echo "5. Test abgeschlossen!"
echo ""
echo "Empfohlene Einstellungen basierend auf GPU:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | while read gpu memory; do
  echo "  GPU: $gpu"
  echo "  VRAM: $memory"

  # Einfache Empfehlungen
  mem_gb=$(echo $memory | grep -oP '\d+' | head -1)
  if [ "$mem_gb" -gt 20 ]; then
    echo "  → Kann llama3.1:70b oder mehr Parallelität nutzen"
    echo "  → Empfohlen: num_workers=5, batch_size=10"
  elif [ "$mem_gb" -gt 12 ]; then
    echo "  → Gut für llama3.1:8b mit hoher Parallelität"
    echo "  → Empfohlen: num_workers=4, batch_size=8"
  else
    echo "  → Begrenzt für parallele Last"
    echo "  → Empfohlen: num_workers=2, batch_size=5"
  fi
done
