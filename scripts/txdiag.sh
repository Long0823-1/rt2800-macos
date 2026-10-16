#!/bin/bash
# Compares the TX ACK success rate of legacy 6 Mbit/s and HT MCS7 (20 MHz) while running the speed test.
# usage: sudo scripts/txdiag.sh [ssid]
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
SOCK=/var/run/rt2800d.sock
SSID="${1:-$(cur_ssid)}"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
ctl() { echo "$*" | nc -U -w 4 "$SOCK" 2>/dev/null; }
acks() { ctl usbstat | sed -n 's/.*TX acked \([0-9]*\) no-ack \([0-9]*\).*/\1 \2/p'; }
one() {  # label ba ampdu mcs bw40
  read a0 n0 < <(acks)
  "$HERE/speedtest.sh" "$SSID" one "$2" "$3" "$4" "$5" | sed 's/^/   /'
  read a1 n1 < <(acks)
  da=$((a1 - a0)); dn=$((n1 - n0))
  awk -v l="$1" -v a="$da" -v n="$dn" 'BEGIN { t=a+n; printf "   >> %s: TX acked %d, no-ack %d (%.1f%% no-ack)\n", l, a, n, t ? 100*n/t : 0 }'
}
echo "### legacy 6 Mbit/s";  one "legacy 6M"  0 0 -1 0
echo "### HT MCS7 20 MHz";   one "HT MCS7/20" 0 0 7 0
echo "### legacy 6 Mbit/s (again, for variance)"; one "legacy 6M #2" 0 0 -1 0
echo "done"
