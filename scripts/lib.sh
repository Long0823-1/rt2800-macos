# Shared helpers of the measurement scripts (sourced, not run).
SOCK="${SOCK:-/var/run/rt2800d.sock}"
ctl() { echo "$*" | nc -U -w 4 "$SOCK" 2>/dev/null; }
hex() { printf %s "$1" | xxd -p | tr -d '\n'; }
# SSID the daemon is connected to (empty when not connected)
cur_ssid() { ctl status | sed -n 's/.*"ssid":"\([^"]*\)".*/\1/p'; }
# name of the utun interface that carries the daemon's IP address
find_utun() {
  local ip
  ip=$(ctl status | sed -n 's/.*"ip":"\([0-9.]*\)".*/\1/p')
  [ -n "$ip" ] || return 1
  ifconfig | awk -v ip="$ip" '/^utun[0-9]+:/{n=$1} $0 ~ ("inet " ip " "){print n}' | tr -d ':'
}
