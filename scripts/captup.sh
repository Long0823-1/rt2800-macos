#!/bin/bash
# Captures a 6 MB upload through the rt2800d utun interface with tcpdump (file: /tmp/rt-up.pcap, readable by the invoking user).
# usage: sudo scripts/captup.sh
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
USER_NAME="${SUDO_USER:-$(stat -f %Su /dev/console)}"
UTUN=$(ifconfig | awk '/^utun[0-9]+:/{n=$1} /inet 192.168.0.2/{print n}' | tr -d ':')
[ -n "$UTUN" ] || { echo "utun not found (connected?)"; exit 1; }
IP=$(dig +short speed.cloudflare.com | head -1)
head -c 6000000 /dev/zero > /tmp/rt2800-up.bin
rm -f /tmp/rt-up.pcap
route add -host "$IP" -interface "$UTUN" >/dev/null 2>&1
tcpdump -i "$UTUN" -n -s 128 -w /tmp/rt-up.pcap "host $IP" >/dev/null 2>&1 &
TD=$!
sleep 1
curl -s -o /dev/null --resolve speed.cloudflare.com:443:$IP --max-time 40 -X POST --data-binary @/tmp/rt2800-up.bin \
  -w "upload: %{size_upload} bytes in %{time_total}s = %{speed_upload} B/s\n" "https://speed.cloudflare.com/__up"
sleep 1
kill $TD 2>/dev/null; wait $TD 2>/dev/null
route delete -host "$IP" >/dev/null 2>&1
chown "$USER_NAME" /tmp/rt-up.pcap; chmod 644 /tmp/rt-up.pcap
rm -f /tmp/rt2800-up.bin
ls -la /tmp/rt-up.pcap
