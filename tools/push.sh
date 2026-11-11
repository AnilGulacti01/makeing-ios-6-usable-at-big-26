#!/usr/bin/env bash
# prototype/ klasorunu telefona kopyalar (/var/mobile/hikaru-ui).
# Cihazda gzip/scp kolayligi olmadigi icin tar stream kullanir.
#   tools/push.sh            -> kopyala
#   tools/push.sh --open     -> kopyala + Safari'de ac
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SSH_HELPER="$HERE/iphone.sh"
REMOTE="/var/mobile/hikaru-ui"

echo "-> prototype telefona gonderiliyor: $REMOTE"
tar cf - -C "$HERE/../prototype" . | "$SSH_HELPER" "rm -rf $REMOTE && mkdir -p $REMOTE && tar xf - -C $REMOTE && ls $REMOTE"

if [ "$1" = "--open" ]; then
  echo "-> Safari'de aciliyor"
  "$SSH_HELPER" "uiopen 'file://$REMOTE/index.html'"
fi

echo "Tamam: file://$REMOTE/index.html"
