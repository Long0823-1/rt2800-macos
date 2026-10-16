#!/bin/bash
# Records what the AP sends during a download with Block Ack enabled (or disabled): per-frame debug lines go to /tmp/rt-ba-<mode>.log
# usage: sudo scripts/badiag.sh <ba: 0|1|3> [ssid]
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
SOCK=/var/run/rt2800d.sock
BA="${1:-1}"; SSID="${2:-$(cur_ssid)}"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
USER_NAME="${SUDO_USER:-$(stat -f %Su /dev/console)}"
ctl() { echo "$*" | nc -U -w 4 "$SOCK" 2>/dev/null; }
hex() { printf %s "$1" | xxd -p | tr -d '\n'; }
state() { ctl status | sed -n 's/.*"state":"\([a-z]*\)".*/\1/p'; }
ctl tune ba "$BA" >/dev/null; ctl tune ampdu 0 >/dev/null; ctl tune mcs -1 >/dev/null
ctl disconnect >/dev/null; sleep 8; ctl use "$(hex "$SSID")" >/dev/null
for i in $(seq 1 90); do sleep 1; [ "$(state)" = connected ] && break; [ $((i % 20)) = 0 ] && ctl use "$(hex "$SSID")" >/dev/null; done
sleep 8
UTUN=$(find_utun)
IP=$(dig +short speed.cloudflare.com | head -1)
route add -host "$IP" -interface "$UTUN" >/dev/null 2>&1
LOG=/var/log/rt2800d.log; START=$(wc -l < $LOG)
ctl rxdebug on >/dev/null
curl -s -o /dev/null --resolve speed.cloudflare.com:443:$IP --max-time 12 -w "download: %{size_download} bytes in %{time_total}s = %{speed_download} B/s\n" "https://speed.cloudflare.com/__down?bytes=25000000"
ctl rxdebug off >/dev/null
route delete -host "$IP" >/dev/null 2>&1
OUT=/tmp/rt-ba-$BA.log
tail -n +$((START + 1)) $LOG > "$OUT"; chown "$USER_NAME" "$OUT"; chmod 644 "$OUT"
ctl status | sed 's/.*"rx_frames"/"rx_frames"/'
ctl usbstat
ctl tune ba 0 >/dev/null
ls -la "$OUT"
