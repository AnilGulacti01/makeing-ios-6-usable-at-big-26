#!/usr/bin/env bash
# Prototipi yerel agda yayinla. Telefondan Safari ile ac.
set -e
PORT="${1:-8080}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/prototype"

IP=$(ipconfig 2>/dev/null | grep -i "IPv4" | head -1 | sed 's/.*: //' | tr -d '\r')
[ -z "$IP" ] && IP="<bilgisayar-ip>"

echo "Sunucu: http://$IP:$PORT"
echo "Telefonda Safari -> http://$IP:$PORT  (Ana Ekrana Ekle)"
echo
exec python -m http.server "$PORT" --bind 0.0.0.0 --directory "$DIR"
