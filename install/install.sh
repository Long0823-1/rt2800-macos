#!/bin/bash
# Installs the rt2800d daemon + rt2800-wifi launcher. Run with: sudo install/install.sh
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
install -d /usr/local/libexec/rt2800 /usr/local/share/rt2800 /var/db/rt2800d /usr/local/bin
install -m 755 "$HERE/port/rt2800d" /usr/local/libexec/rt2800/rt2800d
install -m 644 "$HERE/rt2x00/rt2870.bin" /usr/local/share/rt2800/
install -m 755 "$HERE/bin/rt2800-wifi" /usr/local/bin/rt2800-wifi
install -m 755 "$HERE/install/uninstall.sh" /usr/local/libexec/rt2800/uninstall.sh
cat > /Library/LaunchDaemons/local.rt2800d.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.rt2800d</string>
  <key>ProgramArguments</key><array><string>/usr/local/libexec/rt2800/rt2800d</string><string>daemon</string></array>
  <key>EnvironmentVariables</key><dict><key>RTW89_FW_DIR</key><string>/usr/local/share/rt2800</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardErrorPath</key><string>/var/log/rt2800d.log</string>
  <key>StandardOutPath</key><string>/var/log/rt2800d.log</string>
</dict></plist>
PLIST
chown root:wheel /Library/LaunchDaemons/local.rt2800d.plist; chmod 644 /Library/LaunchDaemons/local.rt2800d.plist
launchctl bootout system /Library/LaunchDaemons/local.rt2800d.plist 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/local.rt2800d.plist
echo "Installed. Use: rt2800-wifi scan | connect <ssid> | status   (log: /var/log/rt2800d.log)"
