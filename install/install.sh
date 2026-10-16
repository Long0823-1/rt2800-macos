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
# menu bar app (built as the invoking user, installed to /Applications, starts at login)
if [ -n "$SUDO_USER" ] && command -v swiftc >/dev/null 2>&1; then
  if sudo -u "$SUDO_USER" "$HERE/menubar/build.sh" "$HERE/menubar/build" >/dev/null 2>&1; then
    pkill -x RT2800WiFi 2>/dev/null || true
    rm -rf "/Applications/RT2800 Wi-Fi.app"
    cp -R "$HERE/menubar/build/RT2800 Wi-Fi.app" /Applications/
    UHOME="$(eval echo "~$SUDO_USER")"
    mkdir -p "$UHOME/Library/LaunchAgents"
    cat > "$UHOME/Library/LaunchAgents/local.rt2800.wifi.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.rt2800.wifi</string>
  <key>ProgramArguments</key><array><string>/Applications/RT2800 Wi-Fi.app/Contents/MacOS/RT2800WiFi</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
    chown "$SUDO_USER" "$UHOME/Library/LaunchAgents/local.rt2800.wifi.plist"
    sudo -u "$SUDO_USER" open "/Applications/RT2800 Wi-Fi.app"
    echo "Menu bar app installed (starts at login; switch it off in its menu)."
  else
    echo "Menu bar app was not built (swiftc failed); the daemon and rt2800-wifi are installed."
  fi
fi
echo "Installed. Use: rt2800-wifi scan | connect <ssid> | status   (log: /var/log/rt2800d.log)"
