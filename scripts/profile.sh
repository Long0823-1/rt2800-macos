#!/bin/bash
# Samples the running rt2800d during a download to see where its threads spend their time (output: /tmp/rt-sample.txt).
# usage: sudo scripts/profile.sh
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
USER_NAME="${SUDO_USER:-$(stat -f %Su /dev/console)}"
UTUN=$(ifconfig | awk '/^utun[0-9]+:/{n=$1} /inet 192.168.0.2/{print n}' | tr -d ':')
[ -n "$UTUN" ] || { echo "utun not found (connected?)"; exit 1; }
PID=$(pgrep -x rt2800d | head -1); [ -n "$PID" ] || { echo "rt2800d not running"; exit 1; }
IP=$(dig +short speed.cloudflare.com | head -1)
route add -host "$IP" -interface "$UTUN" >/dev/null 2>&1
curl -s -o /dev/null --resolve speed.cloudflare.com:443:$IP --max-time 20 -w "download: %{size_download} bytes in %{time_total}s = %{speed_download} B/s\n" "https://speed.cloudflare.com/__down?bytes=60000000" &
CP=$!
sleep 3
sample "$PID" 6 -mayDie -file /tmp/rt-sample.txt >/dev/null 2>&1
wait $CP
route delete -host "$IP" >/dev/null 2>&1
chown "$USER_NAME" /tmp/rt-sample.txt 2>/dev/null; chmod 644 /tmp/rt-sample.txt 2>/dev/null
ls -la /tmp/rt-sample.txt
