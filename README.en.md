# RT2800 Wi-Fi for macOS (experimental)

[日本語](README.md) | English

A userspace macOS Wi-Fi driver for USB adapters with the Ralink **RT5592** chip (for example Buffalo, USB `0411:0253`; 802.11a/b/g/n, 2.4 GHz and 5 GHz).
It runs the upstream Linux `rt2x00` / `rt2800usb` driver almost unmodified on a Linux-kernel-API compatibility layer
(same approach as [mt7601u-macos](https://github.com/Long0823-1/mt7601u-macos) and [rtw89-macos](https://github.com/Long0823-1/rtw89-macos)).

- Supported: 2.4 GHz and 5 GHz, WPA2-PSK / open networks, DHCP and IPv6, menu bar app, `rt2800-wifi` command, auto-connect
- Speed (measured through the adapter, 5 GHz, 40 MHz AP): about 58 Mbit/s down and 24 Mbit/s up
- Not supported: WPA3, sleep/wake, integration into the macOS Wi-Fi settings (traffic goes through a dedicated `utun` interface)
- Tested on one Intel Mac / macOS 26 only. **Experimental software.**

## Install (GUI)

1. Download `RT2800-WiFi-x.y.pkg` from [Releases](../../releases)
2. Right-click → Open (the package is unsigned) and follow the installer
3. Plug in the adapter → pick a network from the Wi-Fi icon in the menu bar

The installer and the menu bar app follow the system language (Japanese / English).

Uninstall: `sudo /usr/local/libexec/rt2800/uninstall.sh`

## Build from source

```bash
scripts/fetch-firmware.sh      # download rt2870.bin from linux-firmware
installer/build-pkg.sh         # builds dist/RT2800-WiFi-0.1.pkg (needs Xcode Command Line Tools)
```

Daemon only:

```bash
cd port && make
RTW89_FW_DIR=../rt2x00 ./rt2800d scan
```

## Usage

Menu bar icon: connection status (signal strength), network list (lock = password required, 2.4G / 5G), connect / disconnect,
**Auto-Connect**, **Use as Default Route**, forget saved networks, **Open at Login**.

Command line:

```
rt2800-wifi scan | list | status
rt2800-wifi connect "SSID"       # asks for the password, saves it and auto-connects later
rt2800-wifi disconnect | forget "SSID" | log | start | stop | restart
```

The default route is **not** changed unless you switch "Use as Default Route" on. To test one destination:
`sudo route add -host <ip> -interface utun4`. Log: `/var/log/rt2800d.log`.
Set `RT2800_LANG=en` or `ja` to force the language of the command line messages.

## Tuning and measuring

Runtime knobs (not saved): `echo "tune ba|ampdu|mcs|bw40 <value>" | sudo nc -U /var/run/rt2800d.sock`.
Defaults: HT MCS5, 40 MHz TX only when the AP is 40 MHz wide, RX Block Ack accepted, TX A-MPDU off, automatic fallback to 6 Mbit/s when more than 8 % of the frames get no ACK.

`scripts/` has the tools used to find the bottlenecks: `speedtest.sh`, `txdiag.sh`, `captup.sh`, `badiag.sh`, `profile.sh`.

## How it works

The daemon `rt2800d` (`port/host/`) opens the USB device through IOKit and runs the upstream `rt2x00` / `rt2800usb` driver together with its own
mac80211 / MLME / WPA2 implementation. The menu bar app (`menubar/`, Swift) talks to the daemon over `/var/run/rt2800d.sock`.

## Known issues

- If the adapter drops off the USB bus (it happened with TX A-MPDU together with 40 MHz TX, and after an unclean exit), unplug and replug it.
- Only one TX chain is used (two chains on 5 GHz draw more current than the USB port gives and the adapter disconnects). `RT_TWO_TX=1` re-enables both.
- TX status is read with one USB control transfer per frame, which limits the speed (the thread is about 83 % busy at 58 Mbit/s).
- There is no real rate control: a fixed MCS with a simple fallback.
- If the handshake fails, first check the password for typos.
