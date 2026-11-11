#!/usr/bin/env bash
# iPhone 4 (iOS 6) uzerinde SSH komutu calistirir.
# Kullanim:
#   tools/iphone.sh "komut"
#   tools/iphone.sh                      -> interaktif kabuk
#   IPHONE_IP=192.168.1.50 tools/iphone.sh "komut"
#   IPHONE_PW=sifre tools/iphone.sh "komut"
#
# Not: iOS 6 sshd'i eski (OpenSSH 6.7), bu yuzden ssh-rsa ve sifre girisi zorunlu.
set -e

IPHONE_IP="${IPHONE_IP:-192.168.1.187}"
IPHONE_PW="${IPHONE_PW:-alpine}"
ASKPASS="$(mktemp -t askpass.XXXXXX)"
trap 'rm -f "$ASKPASS"' EXIT

printf '#!/bin/sh\nprintf "%%s\\n" "$IPHONE_PW"\n' > "$ASKPASS"
chmod +x "$ASKPASS"

export IPHONE_PW SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY=:0

OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
      -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa
      -o PreferredAuthentications=password -o ConnectTimeout=10
      -o LogLevel=ERROR)

if [ $# -eq 0 ]; then
  exec ssh "${OPTS[@]}" "root@$IPHONE_IP"
fi
exec ssh "${OPTS[@]}" "root@$IPHONE_IP" "$*"
