#!/bin/bash
# Builds dist/RT2800-WiFi-<version>.pkg (GUI installer). Needs Xcode command line tools. Usage: installer/build-pkg.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER=0.1
W="$ROOT/installer/build"
rm -rf "$W"; mkdir -p "$W/root" "$ROOT/dist"
make -C "$ROOT/port" rt2800d
[ -f "$ROOT/rt2x00/rt2870.bin" ] || "$ROOT/scripts/fetch-firmware.sh"
"$ROOT/menubar/build.sh" "$W/app"
R="$W/root"
install -d "$R/usr/local/libexec/rt2800" "$R/usr/local/share/rt2800" "$R/usr/local/bin" "$R/Applications" "$R/Library/LaunchDaemons"
install -m 755 "$ROOT/port/rt2800d" "$R/usr/local/libexec/rt2800/rt2800d"
strip -S "$R/usr/local/libexec/rt2800/rt2800d"	# drop debug info (it contains build-machine paths)
install -m 755 "$ROOT/install/uninstall.sh" "$R/usr/local/libexec/rt2800/uninstall.sh"
install -m 644 "$ROOT/rt2x00/rt2870.bin" "$R/usr/local/share/rt2800/rt2870.bin"
install -m 644 "$ROOT/LICENSES/ralink-firmware.txt" "$R/usr/local/share/rt2800/LICENCE.ralink-firmware.txt"
install -m 644 "$ROOT/COPYING" "$R/usr/local/share/rt2800/COPYING"
install -m 755 "$ROOT/bin/rt2800-wifi" "$R/usr/local/bin/rt2800-wifi"
cp -R "$W/app/RT2800 Wi-Fi.app" "$R/Applications/"
cat > "$R/Library/LaunchDaemons/local.rt2800d.plist" <<PLIST
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
chmod +x "$ROOT/installer/scripts/"*
# never relocate the app bundle: otherwise the installer overwrites any other copy with the same bundle id (e.g. a build directory)
pkgbuild --analyze --root "$R" "$W/component.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$W/component.plist"
plutil -replace 0.BundleIsVersionChecked -bool NO "$W/component.plist"
pkgbuild --root "$R" --component-plist "$W/component.plist" --identifier local.rt2800.pkg --version $VER --scripts "$ROOT/installer/scripts" --install-location / "$W/component.pkg"
productbuild --distribution "$ROOT/installer/distribution.xml" --resources "$ROOT/installer/resources" --package-path "$W" "$ROOT/dist/RT2800-WiFi-$VER.pkg"
echo "built: $ROOT/dist/RT2800-WiFi-$VER.pkg"
