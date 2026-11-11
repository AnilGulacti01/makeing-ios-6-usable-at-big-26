#!/usr/bin/env bash
# iOS 18 ikonlarini cihaza kurar (SpringBoard yeniden baslatilir).
#   tools/install_icons.sh            -> acik (light) set
#   tools/install_icons.sh --dark     -> iOS 18 dark (siyah) set
#   tools/install_icons.sh --restore  -> orijinal ikonlara don
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SSH="$HERE/iphone.sh"
REMOTE=/var/mobile/hikaru-theme
BACKUP=/var/mobile/hikaru-backup/icons

SRC_DIR="$HERE/../theme/icons"
if [ "$1" = "--dark" ]; then
  SRC_DIR="$HERE/../theme/icons-dark"
fi

if [ "$1" = "--restore" ]; then
  echo "-> Orijinal ikonlar geri yukleniyor"
  "$SSH" "for d in $BACKUP/*; do a=\${d##*/}; for f in \$d/*.png; do cp \"\$f\" \"/Applications/\$a.app/\${f##*/}\"; done; done; sbreload"
  echo "Tamam."
  exit 0
fi

echo "-> Ikonlar gonderiliyor"
tar cf - -C "$SRC_DIR/.." "$(basename "$SRC_DIR")" \
  | "$SSH" "rm -rf $REMOTE && mkdir -p $REMOTE/icons && tar xf - -C /tmp && cp -r /tmp/$(basename "$SRC_DIR")/. $REMOTE/icons/ && rm -rf /tmp/$(basename "$SRC_DIR")"

echo "-> Yedeklenip degistiriliyor"
"$SSH" "B=$BACKUP; T=$REMOTE/icons; for d in \"\$T\"/*; do app=\${d##*/}; for f in \"\$d\"/*.png; do fn=\${f##*/}; t=\"/Applications/\$app.app/\$fn\"; if [ -f \"\$t\" ]; then mkdir -p \"\$B/\$app\"; [ -f \"\$B/\$app/\$fn\" ] || cp -p \"\$t\" \"\$B/\$app/\$fn\"; cp \"\$f\" \"\$t\"; echo \"  \$app/\$fn\"; else echo \"  ATLANDI (yok): \$app/\$fn\"; fi; done; done"

echo "-> SpringBoard yeniden baslatiliyor"
"$SSH" "sbreload"
echo "Tamam. Geri almak icin: tools/install_icons.sh --restore"
