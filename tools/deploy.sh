#!/usr/bin/env bash
# Prototipi jailbreak'li iPhone'a SSH ile kopyala.
# Kullanim: tools/deploy.sh 192.168.1.50 [--respring]
# Gereksinim: Cydia -> OpenSSH, root sifresi (varsayilan "alpine", degistir).
set -e

IP="$1"
RESPRING="$2"
REMOTE="/var/mobile/hikaru-ui"

if [ -z "$IP" ]; then
  echo "Kullanim: tools/deploy.sh <telefon-ip> [--respring]"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "-> Baglanti testi: root@$IP"
ssh -o ConnectTimeout=6 "root@$IP" "echo baglandi: \$(uname -a)"

echo "-> Dosyalar kopyalaniyor: $REMOTE"
ssh "root@$IP" "mkdir -p $REMOTE"
scp -r "$ROOT/prototype/." "root@$IP:$REMOTE/"

echo "-> Safari'de ac: http://$IP:8080  (yerel sunucu) veya localhost uzerinden file://"
echo "   Alternatif: ssh root@$IP 'safarilauncher $REMOTE/index.html'"

if [ "$RESPRING" = "--respring" ]; then
  echo "-> SpringBoard yeniden baslatiliyor"
  ssh "root@$IP" "killall -9 SpringBoard"
fi

echo "Tamam."
