#!/bin/bash
# Downloads rt2870.bin (Ralink RT2870/RT3070/RT5592 firmware) from linux-firmware into rt2x00/. Usage: scripts/fetch-firmware.sh
set -e
DEST="$(cd "$(dirname "$0")/.." && pwd)/rt2x00/rt2870.bin"
[ -f "$DEST" ] && { echo "already there: $DEST"; exit 0; }
curl -fL "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rt2870.bin" -o "$DEST"
SUM=$(shasum -a 256 "$DEST" | awk '{print $1}')
echo "downloaded $DEST (sha256 $SUM)"
