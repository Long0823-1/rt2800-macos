#!/bin/bash
# Removes the rt2800d daemon and launcher. Run with: sudo /usr/local/libexec/rt2800/uninstall.sh
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
launchctl bootout system /Library/LaunchDaemons/local.rt2800d.plist 2>/dev/null
rm -f /Library/LaunchDaemons/local.rt2800d.plist /usr/local/bin/rt2800-wifi /var/run/rt2800d.sock
rm -rf /usr/local/libexec/rt2800 /usr/local/share/rt2800
echo "Removed. Saved networks remain in /var/db/rt2800d (delete that folder to forget them)."
