// SPDX-License-Identifier: BSD-3-Clause
// Menu bar app for the rt2800d daemon (Buffalo / RT5592 USB Wi-Fi): shows the state, lists networks, connects,
// toggles auto-connect and the default route, and can start at login.
// Talks to the daemon's control socket (/var/run/rt2800d.sock): one command per connection, text/JSON reply.
import Cocoa
import Darwin

// Japanese when the first preferred language is Japanese, English otherwise.
let isJapanese = (Locale.preferredLanguages.first ?? "en").hasPrefix("ja")
func L(_ ja: String, _ en: String) -> String { isJapanese ? ja : en }

let socketPath = ProcessInfo.processInfo.environment["RT2800_SOCK"] ?? "/var/run/rt2800d.sock"
let logPath = "/var/log/rt2800d.log"
let agentLabel = "local.rt2800.wifi"

// MARK: - control socket client

func control(_ command: String) -> String? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    if fd < 0 { return nil }
    defer { close(fd) }
    var tv = timeval(tv_sec: 4, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(socketPath.utf8CString)
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        for (i, b) in bytes.enumerated() where i < raw.count { raw[i] = UInt8(bitPattern: b) }
    }
    let len = socklen_t(MemoryLayout<sockaddr_un>.size)
    let ok = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
    }
    if ok != 0 { return nil }
    let line = Array((command + "\n").utf8)
    if write(fd, line, line.count) < 0 { return nil }
    var out = Data()
    var buf = [UInt8](repeating: 0, count: 8192)
    while true {
        let n = read(fd, &buf, buf.count)
        if n <= 0 { break }
        out.append(buf, count: n)
    }
    return String(data: out, encoding: .utf8)
}

func hex(_ s: String) -> String { s.utf8.map { String(format: "%02x", $0) }.joined() }

// MARK: - model

struct Status {
    var state = "daemon_down"      // daemon_down, starting, no_adapter, idle, scanning, connecting, connected, failed
    var ssid = ""
    var ip = ""
    var signal = 0
    var channel = 0
    var rxRate = ""
    var error = ""
    var uptime = 0
    var defaultRoute = false
    var autoconnect = true
    var known: [String] = []
}

struct Network {
    let ssid: String
    let signal: Int
    let channel: Int
    let band: String
    let secure: Bool
    let known: Bool
}

func fetchStatus() -> Status {
    guard let reply = control("status"),
          let data = reply.data(using: .utf8),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Status() }
    var s = Status()
    s.state = j["state"] as? String ?? "idle"
    s.ssid = j["ssid"] as? String ?? ""
    s.ip = j["ip"] as? String ?? ""
    s.signal = j["signal"] as? Int ?? 0
    s.channel = j["channel"] as? Int ?? 0
    s.rxRate = j["rx_rate"] as? String ?? ""
    s.error = j["error"] as? String ?? ""
    s.uptime = j["uptime"] as? Int ?? 0
    s.defaultRoute = j["default_route"] as? Bool ?? false
    s.autoconnect = j["autoconnect"] as? Bool ?? true
    s.known = j["known"] as? [String] ?? []
    return s
}

func fetchNetworks() -> [Network] {
    guard let reply = control("list"),
          let data = reply.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return arr.compactMap { d in
        guard let ssid = d["ssid"] as? String, !ssid.isEmpty else { return nil }
        return Network(ssid: ssid, signal: d["signal"] as? Int ?? -100, channel: d["channel"] as? Int ?? 0,
                       band: d["band"] as? String ?? "", secure: d["secure"] as? Bool ?? true,
                       known: d["known"] as? Bool ?? false)
    }.sorted { $0.signal > $1.signal }
}

// MARK: - start at login (a per-user LaunchAgent, so the user controls it)

enum LoginItem {
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }
    static var enabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func set(_ on: Bool) {
        if on {
            let exe = Bundle.main.executablePath ?? "/Applications/RT2800 Wi-Fi.app/Contents/MacOS/RT2800WiFi"
            let plist: [String: Any] = [
                "Label": agentLabel,
                "ProgramArguments": [exe],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive",
            ]
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            (plist as NSDictionary).write(to: plistURL, atomically: true)
        } else {
            try? FileManager.default.removeItem(at: plistURL)
        }
    }
}

// MARK: - app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let queue = DispatchQueue(label: "rt2800.control")
    var status = Status()
    var networks: [Network] = []
    var lastScan = Date.distantPast
    var menuOpen = false
    var pollTimer: Timer?
    var fastPollUntil = Date.distantPast
    var lastError = ""
    var lastState = ""

    func applicationDidFinishLaunching(_ n: Notification) {
        menu.delegate = self
        item.menu = menu
        refreshIcon()
        rebuildMenu()
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: polling

    var tickCount = 0
    func tick() {
        tickCount += 1
        let fast = Date() < fastPollUntil || menuOpen
        if fast || tickCount % 3 == 0 { poll() }
    }

    func poll() {
        queue.async {
            let s = fetchStatus()
            DispatchQueue.main.async { self.apply(s) }
        }
    }

    func apply(_ s: Status) {
        let wasFailed = status.state == "failed"
        status = s
        if s.state == "failed", !wasFailed, !s.error.isEmpty, s.error != lastError {
            lastError = s.error
            showFailure(s.error)
        }
        if s.state == "connected" { lastError = "" }
        lastState = s.state
        refreshIcon()
        if menuOpen { rebuildMenu() }
    }

    func requestScan() {
        lastScan = Date()
        queue.async {
            _ = control("scan")
            Thread.sleep(forTimeInterval: 6.0)
            let n = fetchNetworks()
            DispatchQueue.main.async { self.networks = n; if self.menuOpen { self.rebuildMenu() } }
        }
    }

    func loadNetworks() {
        queue.async {
            let n = fetchNetworks()
            DispatchQueue.main.async { self.networks = n; if self.menuOpen { self.rebuildMenu() } }
        }
    }

    // MARK: icon

    func refreshIcon() {
        guard let button = item.button else { return }
        var symbol = "wifi"
        var level: Double = 0
        var tip = ""
        switch status.state {
        case "connected":
            level = max(0.0, min(1.0, Double(status.signal + 90) / 50.0))
            tip = "\(status.ssid) (\(status.signal) dBm)"
        case "connecting", "scanning", "starting":
            symbol = "wifi.exclamationmark"; tip = L("接続中…", "Connecting…")
        case "daemon_down":
            symbol = "exclamationmark.triangle"; tip = L("デーモンが動いていません", "Daemon is not running")
        case "no_adapter":
            symbol = "wifi.slash"; tip = L("アダプタが見つかりません", "Adapter not found")
        case "failed":
            symbol = "wifi.exclamationmark"; tip = status.error
        default:
            symbol = "wifi.slash"; tip = L("未接続", "Not connected")
        }
        var image: NSImage?
        if symbol == "wifi" {
            image = NSImage(systemSymbolName: "wifi", variableValue: level, accessibilityDescription: "Wi-Fi")
        }
        if image == nil { image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Wi-Fi") }
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
    }

    // MARK: menu

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        rebuildMenu()
        poll()
        loadNetworks()
        // scanning leaves the channel for a while: do it automatically only when not connected
        if status.state != "connected" && status.state != "daemon_down" && Date().timeIntervalSince(lastScan) > 20 { requestScan() }
    }

    func menuDidClose(_ menu: NSMenu) { menuOpen = false }

    func disabled(_ title: String) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        m.isEnabled = false
        return m
    }

    func action(_ title: String, _ sel: Selector, _ represented: Any? = nil) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        m.target = self
        m.representedObject = represented
        return m
    }

    func toggle(_ title: String, on: Bool, _ sel: Selector) -> NSMenuItem {
        let m = action(title, sel)
        m.state = on ? .on : .off
        return m
    }

    func uptimeText(_ s: Int) -> String {
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func rebuildMenu() {
        menu.removeAllItems()
        switch status.state {
        case "connected":
            let band = status.channel >= 36 ? "5 GHz" : "2.4 GHz"
            menu.addItem(disabled(L("\(status.ssid) に接続中", "Connected to \(status.ssid)")))
            menu.addItem(disabled("IP \(status.ip)  ·  \(status.signal) dBm  ·  ch\(status.channel) (\(band))"))
            var detail = L("接続時間 ", "Up ") + uptimeText(status.uptime)
            if !status.rxRate.isEmpty && status.rxRate != "-" { detail += L("  ·  受信 ", "  ·  RX ") + status.rxRate.replacingOccurrences(of: " NSS0 160MHz", with: "") }
            menu.addItem(disabled(detail))
        case "connecting", "scanning", "starting":
            menu.addItem(disabled(status.state == "starting" ? L("起動中…", "Starting…") : L("接続中…", "Connecting…")))
        case "failed":
            menu.addItem(disabled(L("接続失敗: ", "Connection failed: ") + status.error))
        case "no_adapter":
            menu.addItem(disabled(L("アダプタが見つかりません (USB を確認)", "Adapter not found (check the USB port)")))
        case "daemon_down":
            menu.addItem(disabled(L("デーモンが動いていません", "The daemon is not running")))
            menu.addItem(action(L("デーモンを起動…", "Start Daemon…"), #selector(startDaemon)))
        default:
            menu.addItem(disabled(L("未接続", "Not connected")))
        }
        menu.addItem(.separator())

        if status.state != "daemon_down" {
            menu.addItem(disabled(L("ネットワーク", "Networks")))
            if networks.isEmpty { menu.addItem(disabled(L("  検索中…", "  Searching…"))) }
            for n in networks.prefix(30) {
                let current = status.state == "connected" && status.ssid == n.ssid
                let bars = n.signal > -55 ? "▂▄▆█" : n.signal > -65 ? "▂▄▆" : n.signal > -75 ? "▂▄" : "▂"
                let band = n.band.hasPrefix("5") ? "5G" : "2.4G"
                let title = NSMutableAttributedString(string: n.ssid)
                title.append(NSAttributedString(string: "   \(band) \(bars) \(n.signal)",
                                                attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                                                             .font: NSFont.menuFont(ofSize: 11)]))
                let m = action("", #selector(selectNetwork(_:)), n.ssid)
                m.attributedTitle = title
                m.state = current ? .on : .off
                if n.secure { m.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "secured") }
                m.indentationLevel = 1
                menu.addItem(m)
            }
            menu.addItem(.separator())
            menu.addItem(action(L("再スキャン", "Rescan"), #selector(rescan)))
            if status.state == "connected" || status.state == "connecting" {
                menu.addItem(action(L("切断", "Disconnect"), #selector(disconnect)))
            }
            menu.addItem(.separator())
            menu.addItem(toggle(L("自動接続", "Auto-Connect"), on: status.autoconnect, #selector(toggleAutoconnect)))
            menu.addItem(toggle(L("この Wi-Fi を既定の経路にする", "Use as Default Route"), on: status.defaultRoute, #selector(toggleRoute)))
            if !status.known.isEmpty {
                let sub = NSMenu()
                for k in status.known { sub.addItem(action(k, #selector(forget(_:)), k)) }
                let parent = NSMenuItem(title: L("保存済みネットワークを削除", "Forget Saved Network"), action: nil, keyEquivalent: "")
                parent.submenu = sub
                menu.addItem(parent)
            }
        }
        menu.addItem(.separator())
        menu.addItem(toggle(L("ログイン時に起動", "Open at Login"), on: LoginItem.enabled, #selector(toggleLogin)))
        menu.addItem(action(L("ログを開く", "Open Log"), #selector(openLog)))
        menu.addItem(NSMenuItem(title: L("終了", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: actions

    @objc func rescan() { requestScan() }

    @objc func disconnect() {
        queue.async { _ = control("disconnect"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func forget(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String else { return }
        queue.async { _ = control("forget \(hex(ssid))"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func toggleAutoconnect() {
        let on = !status.autoconnect
        status.autoconnect = on
        queue.async { _ = control("autoconnect \(on ? "on" : "off")"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func toggleRoute() {
        let on = !status.defaultRoute
        status.defaultRoute = on
        queue.async { _ = control("route \(on ? "on" : "off")"); DispatchQueue.main.async { self.poll() } }
    }

    @objc func toggleLogin() { LoginItem.set(!LoginItem.enabled) }

    @objc func openLog() { NSWorkspace.shared.open(URL(fileURLWithPath: logPath)) }

    // starts the launchd daemon (needs administrator rights: the standard macOS password dialog asks for them)
    @objc func startDaemon() {
        let script = "do shell script \"launchctl bootstrap system /Library/LaunchDaemons/local.rt2800d.plist 2>/dev/null; launchctl kickstart -k system/local.rt2800d\" with administrator privileges"
        queue.async {
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            DispatchQueue.main.async { self.fastPollUntil = Date().addingTimeInterval(30); self.poll() }
        }
    }

    @objc func selectNetwork(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String,
              let n = networks.first(where: { $0.ssid == ssid }) else { return }
        if status.state == "connected" && status.ssid == ssid { return }
        if !n.secure {
            connect(ssid, psk: nil)
        } else if n.known || status.known.contains(ssid) {
            queue.async { _ = control("use \(hex(ssid))"); DispatchQueue.main.async { self.startedConnecting() } }
        } else {
            // the menu is closing; ask for the password on the next run-loop turn
            DispatchQueue.main.async { self.askPassword(ssid) }
        }
    }

    func askPassword(_ ssid: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("「\(ssid)」のパスワード", "Password for “\(ssid)”")
        alert.informativeText = L("WPA2 パスフレーズ (8〜63 文字) を入力してください。", "Enter the WPA2 passphrase (8–63 characters).")
        alert.addButton(withTitle: L("接続", "Connect"))
        alert.addButton(withTitle: L("キャンセル", "Cancel"))
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let psk = field.stringValue
            if psk.utf8.count < 8 || psk.utf8.count > 63 {
                showFailure(L("パスワードは 8〜63 文字で入力してください", "The passphrase must be 8–63 characters long."))
                return
            }
            connect(ssid, psk: psk)
        }
    }

    func connect(_ ssid: String, psk: String?) {
        queue.async {
            let cmd = "connect \(hex(ssid)) " + (psk.map { hex($0) } ?? "-")
            let reply = control(cmd) ?? "error daemon not reachable"
            DispatchQueue.main.async {
                if reply.hasPrefix("error") { self.showFailure(reply) } else { self.startedConnecting() }
            }
        }
    }

    func startedConnecting() {
        status.state = "connecting"
        lastError = ""
        refreshIcon()
        fastPollUntil = Date().addingTimeInterval(45)
        poll()
    }

    func showFailure(_ message: String) {
        let text: String
        switch message {
        case let m where m.contains("wrong password"): text = L("パスワードが違うか、ハンドシェイクに失敗しました。", "Wrong password, or the handshake failed.")
        case let m where m.contains("not found"): text = L("ネットワークが見つかりません。", "The network was not found.")
        case let m where m.contains("DHCP"): text = L("IP アドレスを取得できませんでした (DHCP)。", "Could not get an IP address (DHCP).")
        default: text = message
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("Wi-Fi に接続できません", "Cannot connect to Wi-Fi")
        alert.informativeText = text
        alert.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
