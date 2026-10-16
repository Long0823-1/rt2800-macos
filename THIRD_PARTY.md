# Third-party code

- `rt2x00/` — Linux kernel `drivers/net/wireless/ralink/rt2x00` (GPL-2.0-or-later; copyright of the original authors is kept in every file),
  taken from the Linux tree at commit `2f2f7eee` (2026-10-15). Only these sources are used: `rt2800usb`, `rt2800lib`, `rt2x00{config,crypto,dev,firmware,link,mac,queue,usb}`.
  Two small local edits: the TX chain count and the debug output in `rt2800lib.c` / `rt2x00config.c` (see `git log`).
- `port/compat/` — Linux kernel API compatibility headers (mac80211/cfg80211/usb/skbuff subsets) derived from the Linux kernel (GPL-2.0).
- `port/host/` — userspace mac80211/MLME/WPA2 supplicant, IOKit USB shim and daemon, adapted from
  [Long0823-1/rtw89-macos](https://github.com/Long0823-1/rtw89-macos) and [Long0823-1/mt7601u-macos](https://github.com/Long0823-1/mt7601u-macos) (GPL-2.0, parts BSD-3-Clause).
- `rt2870.bin` firmware (not stored in this repository; `scripts/fetch-firmware.sh` downloads it, the installer package contains it unmodified) — from
  [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/), Copyright (c) 2007 Ralink Technology Corporation.
  Redistributed in binary form without modification under the licence in [`LICENSES/ralink-firmware.txt`](LICENSES/ralink-firmware.txt).
