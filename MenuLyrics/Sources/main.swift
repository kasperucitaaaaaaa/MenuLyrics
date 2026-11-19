import AppKit

final class Marquee: NSView {
    var text = "♫ MenuLyrics" { didSet { needsDisplay = true } }
    var lines: [LyricLine] = [] { didSet { measure(); needsDisplay = true } }
    var displayMode = LyricDisplayMode.scroll { didSet { needsDisplay = true } }
    var duration = 0.0
    var shift = 0.0
    var clock = PlaybackClock()
    private var starts: [Double] = []
    private let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuBarFont(ofSize: 13), .foregroundColor: NSColor.labelColor]
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    private func measure() {
        var x = 0.0
        starts = lines.map { line in
            let start = x
            x += ((line.text.isEmpty ? "♪" : line.text) as NSString).size(withAttributes: attributes).width + 42
            return start
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        let y = (bounds.height - ("Ag" as NSString).size(withAttributes: attributes).height) / 2
        guard !lines.isEmpty else {
            (text as NSString).draw(at: NSPoint(x: 0, y: y), withAttributes: attributes)
            return
        }
        let position = clock.position(at: ProcessInfo.processInfo.systemUptime) + shift
        if displayMode == .jump {
            let line = currentLyric(lines, at: position) ?? "♪"
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            var style = attributes; style[.paragraphStyle] = paragraph
            ((line.isEmpty ? "♪" : line) as NSString).draw(in: NSRect(x: 0, y: y, width: bounds.width, height: bounds.height - y), withAttributes: style)
            return
        }
        let offset = lyricStripOffset(lines: lines, starts: starts, duration: duration, time: position)
        for i in lines.indices {
            let x = bounds.width * 0.15 + starts[i] - offset
            let end = i + 1 < starts.count ? starts[i + 1] : starts[i] + 2000
            if x > bounds.width || bounds.width * 0.15 + end - offset < 0 { continue }
            ((lines[i].text.isEmpty ? "♪" : lines[i].text) as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }
    }
}

final class App: NSObject, NSApplicationDelegate {
    let status = NSStatusBar.system.statusItem(withLength: 300)
    let marquee = Marquee(frame: NSRect(x: 0, y: 0, width: 284, height: 24))
    var lines: [LyricLine] = []
    var key = ""
    var title = ""
    var artist = ""
    var duration = 0.0
    var position = 0.0
    var shift = 0.0
    var busy = false
    var playing = false
    var message = "missing"
    let language = UserDefaults.standard.string(forKey: "language") ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en")
    var lastOutput = ""
    var lastFailed = false
    func t(_ key: String) -> String { (language == "zh" ? chinese : english)[key] ?? key }
    var cache: [String: [LyricLine]] = [:]
    var request: URLSessionDataTask?
    var timer: Timer?
    var poller: Timer?
    let online = NSMenuItem(title: "", action: #selector(toggleOnline), keyEquivalent: "")
    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let timing = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let script = """
    if application "Music" is not running then return "IDLE"
    tell application "Music"
        if player state is stopped then return "IDLE"
        set sep to ASCII character 31
        return (name of current track) & sep & (artist of current track) & sep & ((duration of current track) as text) & sep & (player position as text) & sep & (player state as text)
    end tell
    """
    func applicationDidFinishLaunching(_ notification: Notification) {
        status.button?.addSubview(marquee)
        online.state = UserDefaults.standard.bool(forKey: "online") ? .on : .off
        marquee.displayMode = LyricDisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .scroll
        rebuildMenu()
        timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.marquee.needsDisplay = true }
        RunLoop.main.add(timer!, forMode: .common)
        poller = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(poller!, forMode: .common)
        poll()
    }
    func rebuildMenu() {
        status.button?.toolTip = t("tooltip")
        let menu = NSMenu()
        info.title = title.isEmpty ? t("idle") : "\(title) — \(artist)"
        menu.addItem(info); menu.addItem(.separator())
        online.title = t("online"); online.target = self; menu.addItem(online)
        add(menu, t("import"), #selector(importLRC)); add(menu, t("retry"), #selector(retry))
        menu.addItem(.separator())
        let modeItem = NSMenuItem(title: t("displayMode"), action: nil, keyEquivalent: "")
        let modes = NSMenu()
        for mode in [LyricDisplayMode.scroll, .jump] {
            let item = NSMenuItem(title: t(mode.rawValue), action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = mode.rawValue
            item.state = marquee.displayMode == mode ? .on : .off; modes.addItem(item)
        }
        modeItem.submenu = modes; menu.addItem(modeItem)
        menu.addItem(.separator()); updateTiming(); menu.addItem(timing)
        add(menu, t("earlier"), #selector(earlier)); add(menu, t("later"), #selector(later)); add(menu, t("reset"), #selector(reset))
        menu.addItem(.separator())
        let languageItem = NSMenuItem(title: t("language"), action: nil, keyEquivalent: "")
        let languages = NSMenu()
        for (code, name) in [("zh", "简体中文"), ("en", "English")] {
            let item = NSMenuItem(title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = code; item.state = (UserDefaults.standard.string(forKey: "language") ?? language) == code ? .on : .off
            languages.addItem(item)
        }
        languages.addItem(.separator())
        languages.addItem(NSMenuItem(title: t("restartNote"), action: nil, keyEquivalent: ""))
        languageItem.submenu = languages; menu.addItem(languageItem)
        add(menu, t("help"), #selector(help)); add(menu, t("quit"), #selector(quit))
        status.menu = menu
    }
    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "language")
        for item in sender.menu?.items ?? [] {
            if let value = item.representedObject as? String { item.state = value == code ? .on : .off }
        }
    }
    @objc func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = LyricDisplayMode(rawValue: raw) else { return }
        marquee.displayMode = mode
        UserDefaults.standard.set(raw, forKey: "displayMode")
        for item in sender.menu?.items ?? [] {
            if let value = item.representedObject as? String { item.state = value == raw ? .on : .off }
        }
    }
    func refreshText() {
        marquee.text = lastFailed ? t("permission") : (lastOutput.components(separatedBy: "\u{1f}").count != 5 ? t("waiting") : "♫ \(title) · \(t(message))")
    }
    func add(_ menu: NSMenu, _ title: String, _ selector: Selector) { let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item) }
    func poll() {
        guard !busy else { return }; busy = true
        let source = script
        DispatchQueue.global(qos: .utility).async {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); process.arguments = ["-e", source]
            let pipe = Pipe(); let errors = Pipe(); process.standardOutput = pipe; process.standardError = errors
            var output = ""; var didFail = false
            do { try process.run(); output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""; process.waitUntilExit(); didFail = process.terminationStatus != 0 } catch { didFail = true }
            let failed = didFail; let value = output
            DispatchQueue.main.async { self.busy = false; self.receive(value.trimmingCharacters(in: .newlines), failed: failed) }
        }
    }
    func receive(_ output: String, failed: Bool) {
        lastOutput = output; lastFailed = failed
        let parts = output.components(separatedBy: "\u{1f}")
        guard !failed, parts.count == 5 else {
            playing = false
            marquee.clock.update(position: position, playing: false, now: ProcessInfo.processInfo.systemUptime)
            if !marquee.lines.isEmpty { marquee.lines = [] }
            refreshText()
            return
        }
        title = parts[0]; artist = parts[1]; duration = Double(parts[2]) ?? 0; position = Double(parts[3]) ?? 0; playing = parts[4] == "playing"
        let newKey = "\(title)\u{1f}\(artist)\u{1f}\(Int(duration))"
        if newKey != key {
            marquee.clock = PlaybackClock()
            key = newKey; shift = 0; updateTiming(); request?.cancel(); lines = cache[key] ?? []; message = "missing"
            if lines.isEmpty && online.state == .on { fetch() }
        }
        info.title = "\(title) — \(artist)"
        marquee.clock.update(position: position, playing: playing, now: ProcessInfo.processInfo.systemUptime)
        if marquee.lines != lines { marquee.lines = lines }
        marquee.duration = duration; marquee.shift = shift
        refreshText()
    }
    func fetch() {
        guard !key.isEmpty, online.state == .on else { return }
        let expected = key; message = "loading"
        var url = URLComponents(string: "https://lrclib.net/api/get")!
        url.queryItems = [.init(name: "track_name", value: title), .init(name: "artist_name", value: artist), .init(name: "duration", value: String(Int(duration.rounded())))]
        var req = URLRequest(url: url.url!); req.timeoutInterval = 15; req.setValue("MenuLyrics/1.2", forHTTPHeaderField: "User-Agent")
        request = URLSession.shared.dataTask(with: req) { data, response, error in
            var parsed: [LyricLine] = []
            if let data, (response as? HTTPURLResponse)?.statusCode == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let lrc = json["syncedLyrics"] as? String { parsed = parseLRC(lrc) }
            let result = parsed; let cancelled = (error as? URLError)?.code == .cancelled
            DispatchQueue.main.async {
                guard self.key == expected, self.online.state == .on, !cancelled else { return }
                self.lines = result
                if !result.isEmpty { self.cache[expected] = result }
                self.message = error == nil ? "missing" : "network"
            }
        }; request?.resume()
    }
    @objc func toggleOnline() {
        if online.state == .off {
            let alert = NSAlert(); alert.messageText = t("consentTitle"); alert.informativeText = t("consentBody"); alert.addButton(withTitle: t("enable")); alert.addButton(withTitle: t("cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }; online.state = .on; fetch()
        } else { online.state = .off; request?.cancel() }
        UserDefaults.standard.set(online.state == .on, forKey: "online")
    }
    @objc func retry() { request?.cancel(); fetch() }
    @objc func importLRC() {
        guard !key.isEmpty else { let a = NSAlert(); a.messageText = t("playFirst"); a.runModal(); return }
        let expected = key
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.message = t("chooseFile")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let parsed = parseLRC(try String(contentsOf: url, encoding: .utf8))
            guard !parsed.isEmpty else { throw NSError(domain: "LRC", code: 1, userInfo: [NSLocalizedDescriptionKey: t("invalidLRC")]) }
            guard key == expected else { return }; request?.cancel(); lines = parsed; cache[key] = parsed
        } catch { let a = NSAlert(error: error); a.runModal() }
    }
    func updateTiming() { timing.title = String(format: t("timing"), shift); marquee.shift = shift }
    @objc func earlier() { shift += 0.5; updateTiming() }
    @objc func later() { shift -= 0.5; updateTiming() }
    @objc func reset() { shift = 0; updateTiming() }
    @objc func help() {
        let a = NSAlert(); a.messageText = t("helpTitle")
        a.informativeText = t("helpBody")
        a.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
