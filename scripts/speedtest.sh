#!/bin/bash
# Compares TX/RX tuning settings of the running rt2800d daemon: download and upload through its utun interface.
# usage: sudo scripts/speedtest.sh [ssid]        (default SSID: YOUR_SSID; the network must already be saved)
SOCK=/var/run/rt2800d.sock
SSID="${1:-YOUR_SSID}"
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
ctl() { echo "$*" | nc -U -w 4 "$SOCK" 2>/dev/null; }
hex() { printf %s "$1" | xxd -p | tr -d '\n'; }
UTUN=$(ifconfig | awk '/^utun[0-9]+:/{n=$1} /inet 192.168.0.2/{print n}' | tr -d ':')
status_state() { ctl status | sed -n 's/.*"state":"\([a-z]*\)".*/\1/p'; }
reconnect() {
  ctl disconnect >/dev/null; sleep 8
  ctl use "$(hex "$SSID")" >/dev/null
  # the AP needs a while after a quick leave/join: wait up to 90 s and ask again every 20 s
  for i in $(seq 1 90); do
    sleep 1
    [ "$(status_state)" = connected ] && break
    [ $((i % 20)) = 0 ] && ctl use "$(hex "$SSID")" >/dev/null
  done
  sleep 8
  UTUN=$(ifconfig | awk '/^utun[0-9]+:/{n=$1} /inet 192.168.0.2/{print n}' | tr -d ':')
}
IP=$(dig +short speed.cloudflare.com | head -1)
[ -n "$IP" ] || { echo "dns failed"; exit 1; }
head -c 6000000 /dev/zero > /tmp/rt2800-up.bin
measure() {
  route add -host "$IP" -interface "$UTUN" >/dev/null 2>&1
  d=$(curl -s -o /dev/null --resolve speed.cloudflare.com:443:$IP --max-time 40 -w "%{size_download} %{time_total}" "https://speed.cloudflare.com/__down?bytes=25000000")
  u=$(curl -s -o /dev/null --resolve speed.cloudflare.com:443:$IP --max-time 40 -X POST --data-binary @/tmp/rt2800-up.bin -w "%{size_upload} %{time_total}" "https://speed.cloudflare.com/__up")
  route delete -host "$IP" >/dev/null 2>&1
  echo "$d $u" | awk '{ printf "   down %6.1f Mbit/s (%d B in %.1fs)   up %6.1f Mbit/s (%d B in %.1fs)\n", $1*8/$2/1e6, $1, $2, $3*8/$4/1e6, $3, $4 }'
}
run() {  # name ba ampdu mcs bw40
  echo "== $1  (ba=$2 ampdu=$3 mcs=$4 bw40=$5)"
  ctl tune ba "$2" >/dev/null; ctl tune ampdu "$3" >/dev/null; ctl tune mcs "$4" >/dev/null; ctl tune bw40 "$5" >/dev/null
  reconnect
  [ "$(status_state)" = connected ] || { echo "   not connected"; return; }
  measure
}
echo "interface: $UTUN  target: $IP  ssid: $SSID"
if [ "$2" = one ]; then	# single configuration: speedtest.sh <ssid> one <ba> <ampdu> <mcs> <bw40>
  run "custom" "${3:-0}" "${4:-0}" "${5:--1}" "${6:-0}"
  ctl tune ba 0 >/dev/null; ctl tune ampdu 0 >/dev/null; ctl tune mcs -1 >/dev/null; ctl tune bw40 0 >/dev/null
  rm -f /tmp/rt2800-up.bin; exit 0
fi
run "legacy 6M, no BA (current default)" 0 0 -1 0
run "HT MCS7 20MHz, no BA"                0 0 7 0
run "HT MCS7 40MHz, no BA"                0 0 7 1
run "BA(rx+tx) + A-MPDU, legacy 6M"      3 1 -1 0
run "BA(rx+tx) + A-MPDU, MCS7 20MHz"     3 1 7 0
run "BA(rx+tx) + A-MPDU, MCS7 40MHz"     3 1 7 1
ctl tune ba 0 >/dev/null; ctl tune ampdu 0 >/dev/null; ctl tune mcs -1 >/dev/null; ctl tune bw40 0 >/dev/null
echo "(settings reset to the defaults; runtime only, nothing is saved)"
rm -f /tmp/rt2800-up.bin
