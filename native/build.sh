#!/usr/bin/env bash
# HikaruUI tweak'ini ve Ayarlar bundle'ini WSL (Ubuntu) icinde armv7 olarak derler.
# Gereken: clang, iPhoneOS9.3.sdk (theos altinda), cctools-port ld64 (/usr/local/bin/arm-apple-darwin11-ld), ldid
#
# Kullanim (Windows'tan):
#   wsl -d Ubuntu -e bash -lc 'bash "/mnt/c/.../native/build.sh"'
#
# Not: iOS 9.3 SDK'si .tbd sembol dosyalari kullaniyor; Apple ld64 bunlari okuyamaz.
# Bu yuzden link asamasinda -nostdlib + -undefined dynamic_lookup kullaniyoruz:
# semboller calisma aninda SpringBoard/Preferences'tan cozulur (tweak'ler icin normal yol).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${SDK:-/root/theos/sdks/iPhoneOS9.3.sdk}"
LD64="${LD64:-/usr/local/bin/arm-apple-darwin11-ld}"
OUT="$HERE/build"
mkdir -p "$OUT"

echo "==> Derleniyor (armv7)"
clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fobjc-arc -O2 -Wall \
      -Wno-deprecated-declarations -c "$HERE/HikaruUI.m" -o "$OUT/HikaruUI.o"

echo "==> Linkleniyor"
clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD64" \
      -nostdlib -dynamiclib -Wl,-undefined,dynamic_lookup \
      -o "$OUT/HikaruUI.dylib" "$OUT/HikaruUI.o" 2>&1 | grep -v "dynamic_lookup is deprecated" || true

echo "==> Imzalanior (ldid)"
ldid -S "$OUT/HikaruUI.dylib"

echo "==> Ayarlar bundle'i derleniyor"
clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fobjc-arc -O2 -Wall \
      -Wno-deprecated-declarations -c "$HERE/HikaruPrefs.m" -o "$OUT/HikaruPrefs.o"

clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD64" \
      -nostdlib -bundle -Wl,-undefined,dynamic_lookup \
      -o "$OUT/HikaruPrefs" "$OUT/HikaruPrefs.o" 2>&1 | grep -v "dynamic_lookup is deprecated" || true

ldid -S "$OUT/HikaruPrefs"

ls -l "$OUT/HikaruUI.dylib" "$OUT/HikaruPrefs"
echo BUILD_OK
