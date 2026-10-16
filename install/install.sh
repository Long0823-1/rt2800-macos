#!/bin/bash
# Installs the mt7601ud daemon + mt7601u-wifi launcher. Run with: sudo install/install.sh
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
install -d /usr/local/libexec/mt7601u /usr/local/share/mt7601u /var/db/mt7601ud /usr/local/bin
install -m 755 "$HERE/port/mt7601ud" /usr/local/libexec/mt7601u/mt7601ud
install -m 644 "$HERE/mt7601u/mt7601u.bin" /usr/local/share/mt7601u/
install -m 755 "$HERE/bin/mt7601u-wifi" /usr/local/bin/mt7601u-wifi
cat > /Library/LaunchDaemons/local.mt7601ud.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.mt7601ud</string>
  <key>ProgramArguments</key><array><string>/usr/local/libexec/mt7601u/mt7601ud</string><string>daemon</string></array>
  <key>EnvironmentVariables</key><dict><key>RTW89_FW_DIR</key><string>/usr/local/share/mt7601u</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>StandardErrorPath</key><string>/var/log/mt7601ud.log</string>
  <key>StandardOutPath</key><string>/var/log/mt7601ud.log</string>
</dict></plist>
PLIST
chown root:wheel /Library/LaunchDaemons/local.mt7601ud.plist; chmod 644 /Library/LaunchDaemons/local.mt7601ud.plist
launchctl bootout system /Library/LaunchDaemons/local.mt7601ud.plist 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/local.mt7601ud.plist
echo "Installed. Use: mt7601u-wifi scan | connect <ssid> | status   (log: /var/log/mt7601ud.log)"
