#!/bin/bash
# Removes MT7601U Wi-Fi (daemon, launcher, menu bar app). Run with: sudo /usr/local/libexec/mt7601u/uninstall.sh
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
USER_NAME="$(stat -f %Su /dev/console)"
[ -n "$USER_NAME" ] && launchctl bootout "gui/$(id -u "$USER_NAME")/local.mt7601u.wifi" 2>/dev/null
launchctl bootout system /Library/LaunchDaemons/local.mt7601ud.plist 2>/dev/null
rm -f /Library/LaunchDaemons/local.mt7601ud.plist /Library/LaunchAgents/local.mt7601u.wifi.plist /usr/local/bin/mt7601u-wifi /var/run/mt7601ud.sock
rm -rf "/Applications/MT7601U Wi-Fi.app" /usr/local/libexec/mt7601u /usr/local/share/mt7601u
pkgutil --forget local.mt7601u.pkg >/dev/null 2>&1
echo "Removed. Saved networks remain in /var/db/mt7601ud (delete that folder to forget them)."
