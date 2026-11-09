import AppKit
import SwiftUI

enum Act: Int, CaseIterable { case music, call, focus, timer, download, charging }

enum EvKind { case notif, volume, device, shot, file, nowPlaying, timerDone, focus, charging, lowBattery, charged, meeting, welcome }

final class IslandEvent: Identifiable {
    let id = UUID()
    let kind: EvKind
    var title = "", body = "", app = "", bundle = "", otp = ""
    var url: URL?
    var icon: NSImage?
    var image: NSImage?
    var accent: Color = Palette.blue
    var remain: Double
    var total: Double
    var stack = 1
    var touched = false
    var date = Date()
    var copiedAt: Date?
    var value: Double = 0
    var bytes: Int64 = 0
    var meetingStart: Date?

    init(_ kind: EvKind, seconds: Double) {
        self.kind = kind
        remain = seconds
        total = seconds
    }
}

enum Mode: Equatable {
    case hidden, idle, peek, compact(Act), expanded(Act), event(UUID), launcher
}

struct Countdown: Equatable {
    var on = false, paused = false
    var endAt = Date(), left: Double = 0
    var total = 0
    var remaining: Double { paused ? left : max(0, endAt.timeIntervalSinceNow) }
    var progress: Double { total > 0 ? 1 - remaining / Double(total) : 0 }
}

struct Download: Equatable {
    var name: String
    var bytes: Int64
    var fraction: Double
    var updated: Date
}

struct RecentNotif: Identifiable {
    let id = UUID()
    let app: String, bundle: String, title: String, body: String
    let icon: NSImage?
    let date: Date
}

struct LaunchResult: Identifiable {
    enum Kind { case app, timer, focus, settings }
    let id = UUID()
    let kind: Kind
    let name: String
    var path = ""
    var seconds = 0
}

final class IslandModel: ObservableObject {
    static let panelSize = CGSize(width: 760, height: 600)

    // geometry of the screen's notch (or the fake one on displays without a notch)
    @Published var notch = CGSize(width: 200, height: 32)
    @Published var hasNotch = true

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var bubbleAct: Act?
    @Published var hovering = false
    @Published var clock = Date()
    @Published var pressing = false

    // music
    @Published var np = NowPlaying()
    @Published var art: NSImage?
    @Published var artAccent: Color = Palette.pink
    var pausedAt = Date.distantPast

    // sound
    @Published var volume: Float = 0.5
    @Published var muted = false
    @Published var outputName = ""
    @Published var outputBT = false

    // privacy / calls
    @Published var micInUse = false
    @Published var cameraInUse = false
    @Published var micMuted = false
    var callSince = Date()

    // battery
    @Published var battery = BatteryState()

    // files
    @Published var downloads: [String: Download] = [:]

    // events & notifications
    @Published var events: [IslandEvent] = []
    @Published var recent: [RecentNotif] = []
    @Published var unseen = 0
    var later: [(Date, IslandEvent)] = []
    @Published var notifAccess = false

    // timers
    @Published var timer = Countdown()
    @Published var focus = Countdown()
    @Published var focusBreak = false
    @Published var focusRound = 1

    // expanded / launcher
    @Published var expanded: Act?
    @Published var launcherOpen = false
    @Published var query = "" { didSet { search() } }
    @Published var results: [LaunchResult] = []
    @Published var selection = 0
    @Published var apps: [AppEntry] = []
    @Published var meetings: [MeetingInfo] = []

    var preferAct: Act?
    var pausedUntil: Date?
    @Published var peek = false
    var demo = false
    var alerted = Set<String>()

    // wired up by the app
    var media: MediaSource?
    var audio: AudioSource?
    var onWantKey: ((Bool) -> Void)?
    var onOpenSettings: (() -> Void)?
    private var ticker: Timer?

    // MARK: lifecycle

    func startTicking() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    var paused: Bool { if let p = pausedUntil { return Date() < p } else { return false } }

    // MARK: activities

    var musicActive: Bool {
        guard Prefs.b(.music), np.has else { return false }
        return np.playing || Date().timeIntervalSince(pausedAt) < 45
    }

    var downloadActive: Bool { downloads.values.contains { Date().timeIntervalSince($0.updated) < 30 } }
    var currentDownload: Download? { downloads.values.max { $0.updated < $1.updated } }
    var callActive: Bool { Prefs.b(.calls) && micInUse && Date().timeIntervalSince(callSince) > 2 }

    var acts: [Act] {
        var a: [Act] = []
        if musicActive { a.append(.music) }
        if callActive { a.append(.call) }
        if focus.on { a.append(.focus) }
        if timer.on { a.append(.timer) }
        if downloadActive { a.append(.download) }
        if Prefs.b(.battery) && Prefs.b(.chargingStay) && battery.present && battery.onAC && !battery.charged { a.append(.charging) }
        return a
    }

    func color(_ a: Act) -> Color {
        switch a {
        case .music: return artAccent
        case .call: return micMuted ? Palette.red : Palette.green
        case .focus: return focusBreak ? Palette.blue : Palette.green
        case .timer: return Palette.orange
        case .download: return Palette.blue
        case .charging: return Palette.green
        }
    }

    func event(_ id: UUID) -> IslandEvent? { events.first { $0.id == id } }
    var currentEvent: IslandEvent? { if case .event(let id) = mode { return event(id) } else { return nil } }

    // MARK: deciding what to show

    func refresh() {
        let a = acts
        if let e = expanded, !a.contains(e) { expanded = nil }
        let chosen: Act? = a.contains(where: { $0 == preferAct }) ? preferAct : a.first
        var bubble: Act?
        if a.count > 1, let c = chosen, let i = a.firstIndex(of: c) { bubble = a[(i + 1) % a.count] }
        var m: Mode
        if paused { m = .hidden }
        else if launcherOpen { m = .launcher }
        else if let e = expanded { m = .expanded(e) }
        else if let e = events.first { m = .event(e.id) }
        else if let c = chosen { m = .compact(c) }
        else if peek { m = .peek }
        else { m = .idle }
        if case .compact = m {} else { bubble = nil }
        if m != mode { mode = m }
        if bubble != bubbleAct { bubbleAct = bubble }
    }

    // MARK: sizes (points). Widths include the little "ears" that flare into the top edge.

    func ear(_ m: Mode) -> CGFloat {
        switch m {
        case .hidden, .idle: return 6
        case .peek, .compact: return 7
        default: return 14
        }
    }

    func bottomRadius(_ m: Mode) -> CGFloat {
        switch m {
        case .hidden, .idle, .peek, .compact: return 11
        case .launcher: return 30
        default: return 26
        }
    }

    func wing(_ a: Act) -> CGFloat {
        switch a {
        case .music: return 58
        case .call, .focus: return 78
        case .timer: return 70
        case .download: return 66
        case .charging: return 74
        }
    }

    func size(_ m: Mode) -> CGSize {
        let nh = notch.height, nw = notch.width
        switch m {
        case .hidden: return hasNotch ? CGSize(width: nw + 12, height: nh) : .zero
        case .idle: return CGSize(width: nw + 12, height: nh)
        case .peek: return CGSize(width: nw + 2 * 92 + 14, height: nh)
        case .compact(let a): return CGSize(width: nw + 2 * wing(a) + 14, height: nh)
        case .expanded(let a):
            switch a {
            case .music: return CGSize(width: 480, height: nh + 168)
            case .call: return CGSize(width: 440, height: nh + 112)
            case .focus, .timer: return CGSize(width: 420, height: nh + 136)
            case .download: return CGSize(width: 440, height: nh + 96)
            case .charging: return CGSize(width: 420, height: nh + 92)
            }
        case .event(let id): return eventSize(event(id))
        case .launcher: return CGSize(width: 580, height: nh + launcherHeight)
        }
    }

    func eventSize(_ e: IslandEvent?) -> CGSize {
        let nh = notch.height, nw = notch.width
        guard let e else { return CGSize(width: nw + 12, height: nh) }
        switch e.kind {
        case .volume: return CGSize(width: nw + 2 * 96 + 14, height: nh)
        case .charging, .lowBattery, .charged: return CGSize(width: nw + 2 * 84 + 14, height: nh)
        case .notif:
            let w: CGFloat = 460
            let textW = w - 28 - 72 - 22 - (e.otp.isEmpty || !Prefs.b(.otp) ? 0 : 118)
            let bodyH = e.body.isEmpty ? 0 : min(textHeight(e.body, width: textW, size: 13), 34)
            return CGSize(width: w, height: nh + max(66, 14 + 17 + 19 + bodyH + 16))
        case .device: return CGSize(width: 400, height: nh + 60)
        case .shot: return CGSize(width: 480, height: nh + 108)
        case .file: return CGSize(width: 460, height: nh + 72)
        case .nowPlaying: return CGSize(width: 440, height: nh + 64)
        case .timerDone: return CGSize(width: 420, height: nh + 112)
        case .focus: return CGSize(width: 420, height: nh + 64)
        case .meeting: return CGSize(width: 460, height: nh + 72)
        case .welcome: return CGSize(width: 480, height: nh + 70)
        }
    }

    var launcherHeight: CGFloat {
        if !query.isEmpty { return 128 + CGFloat(max(1, results.count)) * 42 + 14 }
        let rows = min(3, recent.count)
        var h: CGFloat = 128 + 92 + 70 + 34
        h += rows > 0 ? CGFloat(rows) * 44 : 36
        if !notifAccess { h += 40 }
        return h + 16
    }

    func textHeight(_ s: String, width: CGFloat, size: CGFloat) -> CGFloat {
        let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size)])
        return ceil(a.boundingRect(with: NSSize(width: width, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    }

    /// Where the island is inside the panel (top-left origin), for click-through decisions.
    var hitRect: CGRect {
        let s = size(mode)
        let r = CGRect(x: (Self.panelSize.width - s.width) / 2, y: 0, width: s.width, height: s.height)
        if bubbleAct != nil {
            let b = notch.height
            return r.union(CGRect(x: r.maxX + 7, y: 0, width: b, height: b))
        }
        return r
    }

    // MARK: glow

    var glowLevel: Double {
        let level = Prefs.i(.glow)
        if level == 0 { return 0 }
        switch mode {
        case .hidden, .idle, .peek: return level == 3 && mode != .hidden ? 0.45 : 0
        case .event:
            guard let e = currentEvent else { return 0 }
            if e.kind == .volume { return level == 3 ? 0.5 : 0 }
            return 1
        case .compact(let a), .expanded(let a):
            if a == .music && np.playing && level >= 2 { return 0.75 }
            if a == .charging && level >= 2 { return 0.8 }
            return level == 3 ? 0.6 : 0
        case .launcher: return level == 3 ? 0.5 : 0
        }
    }

    var glowColors: [Color] {
        switch Prefs.i(.glowColors) {
        case 1: return Palette.aurora
        case 2: return Palette.timeOfDay()
        default: break
        }
        var base: Color?
        switch mode {
        case .event:
            if let e = currentEvent {
                switch e.kind {
                case .nowPlaying: base = artAccent
                case .charging, .charged: base = Palette.green
                case .lowBattery: base = Palette.red
                case .timerDone: base = Palette.orange
                case .focus: base = focusBreak ? Palette.blue : Palette.green
                case .welcome: return Palette.aurora
                default: base = e.accent
                }
            }
        case .compact(let a), .expanded(let a): base = color(a)
        default: break
        }
        guard let b = base else { return Palette.timeOfDay() }
        let ns = NSColor(b)
        return [b, Color(nsColor: shifted(ns, 38)), b, Color(nsColor: shifted(ns, -38))]
    }

    // MARK: events

    func push(_ e: IslandEvent, front: Bool = false) {
        if front { events.insert(e, at: 0) } else { events.append(e) }
        while events.count > 12 {
            if let i = events.lastIndex(where: { $0.kind == .notif }) { events.remove(at: i); unseen += 1 } else { events.removeLast() }
        }
        refresh()
    }

    func remove(_ e: IslandEvent) {
        if e.kind == .notif && !e.touched { unseen += 1 }
        events.removeAll { $0.id == e.id }
        refresh()
    }

    // MARK: tick

    func tick() {
        let now = Date()
        if timer.on && !timer.paused && now >= timer.endAt { timerFinished() }
        if focus.on && !focus.paused && now >= focus.endAt { focusNext() }
        let due = later.filter { $0.0 <= now }
        if !due.isEmpty {
            later.removeAll { $0.0 <= now }
            for (_, e) in due { e.remain = e.total; e.touched = false; push(e) }
        }
        if let e = currentEvent {
            if !hovering && !pressing { e.remain -= 0.25 }
            if e.remain <= 0 { remove(e) }
        }
        let stale = downloads.filter { now.timeIntervalSince($0.value.updated) > 60 }.map { $0.key }
        for k in stale { downloads[k] = nil }
        if Int(now.timeIntervalSince1970) != Int(clock.timeIntervalSince1970) { clock = now }
        refresh()
    }

    // MARK: user actions

    func tapBody() {
        switch mode {
        case .idle, .peek, .hidden: openLauncher()
        case .compact(let a): expand(a)
        case .expanded: collapse()
        case .event:
            guard let e = currentEvent else { return }
            e.touched = true
            switch e.kind {
            case .notif:
                AppInfo.open(e.bundle)
                recent.removeAll { $0.date == e.date && $0.bundle == e.bundle }
                remove(e)
            case .shot, .file:
                if let u = e.url { NSWorkspace.shared.open(u) }
                remove(e)
            case .nowPlaying: remove(e); expand(.music)
            case .device: remove(e)
            case .meeting:
                if let u = e.url { NSWorkspace.shared.open(u) }
                remove(e)
            case .welcome: remove(e); openLauncher()
            default: break
            }
        case .launcher: break
        }
    }

    func expand(_ a: Act) {
        expanded = a
        if a == .call, let au = audio { micMuted = au.micMuted }
        haptic()
        refresh()
    }

    func collapse() {
        guard launcherOpen || expanded != nil else { return }
        let hadKey = launcherOpen
        launcherOpen = false
        expanded = nil
        query = ""
        refresh()
        if hadKey { onWantKey?(false) }
    }

    func openLauncher() {
        if paused { pausedUntil = nil }
        expanded = nil
        query = ""
        unseen = 0
        launcherOpen = true
        if apps.isEmpty { apps = AppCatalog.load() }
        haptic()
        refresh()
        onWantKey?(true)
    }

    func toggleLauncher() { if launcherOpen { collapse() } else { openLauncher() } }

    func clickedOutside() {
        collapse()
    }

    func setHover(_ inside: Bool, inZone: Bool) {
        if inside != hovering { hovering = inside }
        let wantPeek = Prefs.b(.hoverPeek) && inZone && (mode == .idle || mode == .peek)
        if wantPeek != peek {
            peek = wantPeek
            if wantPeek { haptic() }
            refresh()
        }
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        switch mode {
        case .event:
            if let e = currentEvent, e.kind == .notif {
                if dy > 6 { e.touched = true; remove(e) }      // flick up to dismiss
                return
            }
        case .compact:
            if abs(dx) > abs(dy) && abs(dx) > 4 { switchAct(dx > 0 ? -1 : 1); return }
        case .launcher: return
        default: break
        }
        guard Prefs.b(.scrollVolume), let au = audio, abs(dy) > 0.5 else { return }
        au.setVolume((muted ? 0 : volume) + Float(dy) * 0.006)
    }

    private var lastSwitch = Date.distantPast
    func switchAct(_ dir: Int) {
        guard Date().timeIntervalSince(lastSwitch) > 0.35 else { return }
        let a = acts
        guard a.count > 1, case .compact(let cur) = mode, let i = a.firstIndex(of: cur) else { return }
        lastSwitch = Date()
        preferAct = a[(i + a.count + dir) % a.count]
        haptic()
        refresh()
    }

    func tapBubble() {
        if let b = bubbleAct { preferAct = b; haptic(); refresh() }
    }

    // MARK: music

    func mediaCommand(_ c: MediaCommand) {
        media?.send(c)
    }

    func seek(_ fraction: Double) {
        guard np.duration > 0 else { return }
        media?.seek(fraction * np.duration)
    }

    func openPlayer() {
        if !np.bundle.isEmpty { AppInfo.open(np.bundle) }
        collapse()
    }

    func mediaUpdated(_ n: NowPlaying, _ image: NSImage?) {
        let old = np
        if n.artId != old.artId || (image != nil) != (art != nil) {
            art = image
            artAccent = Color(nsColor: accentColor(image) ?? NSColor(Palette.pink))
        }
        if old.playing && !n.playing { pausedAt = Date() }
        if n != old { np = n }
        if Prefs.b(.music) && Prefs.b(.nowPlaying) && n.playing && !old.title.isEmpty && old.title != n.title,
           case .compact(.music) = mode, !paused {
            events.removeAll { $0.kind == .nowPlaying }
            push(IslandEvent(.nowPlaying, seconds: 3.2))
        }
        if n.playing && !old.playing && preferAct == nil { preferAct = .music }
        refresh()
    }

    // MARK: sound

    func volumeChanged(_ v: Float, _ m: Bool) {
        let changed = abs(v - volume) > 0.001 || m != muted
        volume = v
        muted = m
        guard changed, Prefs.b(.volumeHUD), !paused else { return }
        if case .expanded(.music) = mode { return }
        if let e = events.first(where: { $0.kind == .volume }) {
            e.remain = e.total
            if events.first?.id != e.id { events.removeAll { $0.id == e.id }; events.insert(e, at: 0) }
            refresh()
            return
        }
        push(IslandEvent(.volume, seconds: 1.6), front: true)
    }

    func deviceChanged(_ name: String, _ bt: Bool) {
        outputName = name
        outputBT = bt
        guard Prefs.b(.outputDevice), !paused, !name.isEmpty else { return }
        events.removeAll { $0.kind == .device }
        let e = IslandEvent(.device, seconds: 2.8)
        e.title = name
        e.accent = Palette.blue
        push(e, front: true)
    }

    func micChanged(_ on: Bool) {
        if on && !micInUse { callSince = Date(); if let au = audio { micMuted = au.micMuted } }
        micInUse = on
        refresh()
    }

    func toggleMic() {
        guard let au = audio else { return }
        au.setMicMuted(!au.micMuted)
        micMuted = au.micMuted
    }

    // MARK: battery

    func batteryChanged(_ b: BatteryState) {
        let old = battery
        battery = b
        guard b.present, Prefs.b(.battery), !paused, !demo else { return }
        if b.onAC && !old.onAC && old.present {
            events.removeAll { $0.kind == .charging || $0.kind == .lowBattery }
            let e = IslandEvent(.charging, seconds: 4)
            e.value = Double(b.percent)
            e.accent = Palette.green
            push(e, front: true)
            playSound("Pop")
        }
        if Prefs.b(.lowBattery) && !b.onAC && old.present {
            for t in [20, 10, 5] where b.percent <= t && old.percent > t {
                let e = IslandEvent(.lowBattery, seconds: 6)
                e.value = Double(b.percent)
                e.accent = Palette.red
                push(e, front: true)
            }
        }
        if b.onAC && b.percent >= 100 && old.percent < 100 && old.present {
            let e = IslandEvent(.charged, seconds: 4)
            e.value = 100
            push(e)
        }
        refresh()
    }

    // MARK: notifications

    func notification(_ n: NotifItem) {
        guard Prefs.b(.notifs) else { return }
        let info = AppInfo.lookup(n.bundle)
        let title = n.subtitle.isEmpty ? n.title : n.title + " · " + n.subtitle
        let date = Date()
        recent.insert(RecentNotif(app: info.name, bundle: n.bundle, title: title, body: n.body, icon: info.icon, date: date), at: 0)
        if recent.count > 30 { recent.removeLast(recent.count - 30) }
        if paused { unseen += 1; return }
        let otp = Prefs.b(.otp) ? (findOTP(n.title, n.body) ?? "") : ""
        let accent = Color(nsColor: accentColor(info.icon) ?? NSColor(Palette.blue))
        if let e = events.first(where: { $0.kind == .notif && $0.bundle == n.bundle }) {
            e.title = title; e.body = n.body; e.otp = otp; e.date = date
            e.stack += 1
            e.remain = e.total
            e.touched = false
            objectWillChange.send()
            refresh()
            return
        }
        let e = IslandEvent(.notif, seconds: Double(otp.isEmpty ? Prefs.i(.notifSeconds) : max(Prefs.i(.notifSeconds), 12)))
        e.app = info.name; e.bundle = n.bundle; e.title = title; e.body = n.body; e.otp = otp
        e.icon = info.icon; e.accent = accent; e.date = date
        push(e)
    }

    func copyOTP(_ e: IslandEvent) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(e.otp, forType: .string)
        e.copiedAt = Date()
        e.touched = true
        e.remain = min(e.remain, 1.6)
        objectWillChange.send()
        haptic()
    }

    func snooze(_ e: IslandEvent) {
        e.touched = true
        remove(e)
        later.append((Date().addingTimeInterval(600), e))
    }

    func dismiss(_ e: IslandEvent) {
        e.touched = true
        remove(e)
    }

    func openRecent(_ r: RecentNotif) {
        recent.removeAll { $0.id == r.id }
        collapse()
        AppInfo.open(r.bundle)
    }

    func clearRecent() {
        recent.removeAll()
        unseen = 0
    }

    // MARK: files

    func fileEvent(_ f: FileEvent) {
        switch f.kind {
        case .progress:
            guard Prefs.b(.downloads) else { return }
            downloads[f.url.path] = Download(name: f.name, bytes: f.bytes, fraction: f.fraction, updated: Date())
            refresh()
        case .progressEnded:
            downloads[f.url.path] = nil
            refresh()
        case .screenshot, .downloaded:
            if f.kind == .screenshot && !Prefs.b(.screenshots) { return }
            if f.kind == .downloaded && !Prefs.b(.downloads) { return }
            if f.kind == .downloaded { downloads = downloads.filter { !$0.key.hasPrefix(f.url.path) && $0.value.name != f.name } }
            guard !paused else { return }
            let e = IslandEvent(f.kind == .screenshot ? .shot : .file, seconds: f.kind == .screenshot ? 6 : 5)
            e.url = f.url
            e.title = f.name
            e.bytes = f.bytes
            if f.kind == .screenshot {
                e.image = NSImage(contentsOf: f.url)
                e.accent = Color(nsColor: accentColor(e.image) ?? NSColor(Palette.purple))
            } else {
                e.icon = NSWorkspace.shared.icon(forFile: f.url.path)
                e.accent = Palette.blue
            }
            push(e)
        }
    }

    func copyImage(_ e: IslandEvent) {
        guard let u = e.url else { return }
        NSPasteboard.general.clearContents()
        if let img = NSImage(contentsOf: u) { NSPasteboard.general.writeObjects([img]) }
        e.copiedAt = Date()
        e.remain = max(e.remain, 2)
        objectWillChange.send()
        haptic()
    }

    func markup(_ e: IslandEvent) {
        guard let u = e.url else { return }
        if let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            NSWorkspace.shared.open([u], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(u)
        }
        remove(e)
    }

    func reveal(_ e: IslandEvent) {
        if let u = e.url { NSWorkspace.shared.activateFileViewerSelecting([u]) }
        remove(e)
    }

    // MARK: timers & focus

    func startTimer(_ sec: Int) {
        timer = Countdown(on: true, paused: false, endAt: Date().addingTimeInterval(Double(sec)), left: 0, total: sec)
        preferAct = .timer
        refresh()
    }

    func startFocus() {
        let sec = Prefs.i(.focusMin) * 60
        focus = Countdown(on: true, paused: false, endAt: Date().addingTimeInterval(Double(sec)), left: 0, total: sec)
        focusBreak = false
        focusRound = 1
        preferAct = .focus
        refresh()
    }

    func stopFocus() { focus.on = false; collapse(); refresh() }
    func stopTimer() { timer.on = false; collapse(); refresh() }

    func togglePause(_ a: Act) {
        var c = a == .focus ? focus : timer
        if c.paused { c.endAt = Date().addingTimeInterval(c.left); c.paused = false }
        else { c.left = c.remaining; c.paused = true }
        if a == .focus { focus = c } else { timer = c }
    }

    func addMinute() {
        var c = timer
        if c.paused { c.left += 60 } else { c.endAt = c.endAt.addingTimeInterval(60) }
        c.total += 60
        timer = c
    }

    private func timerFinished() {
        let total = timer.total
        timer.on = false
        if expanded == .timer { expanded = nil }
        let e = IslandEvent(.timerDone, seconds: 60)
        e.body = minLabel(total) + " timer"
        e.accent = Palette.orange
        push(e, front: true)
        playSound("Glass")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            if self?.events.contains(where: { $0.id == e.id }) == true { playSound("Glass") }
        }
    }

    func focusNext() {
        focusBreak.toggle()
        if !focusBreak { focusRound += 1 }
        let sec = (focusBreak ? Prefs.i(.breakMin) : Prefs.i(.focusMin)) * 60
        focus = Countdown(on: true, paused: false, endAt: Date().addingTimeInterval(Double(sec)), left: 0, total: sec)
        let e = IslandEvent(.focus, seconds: 5)
        e.title = focusBreak ? "Time for a break" : "Back to focus"
        e.body = focusBreak ? minLabel(sec) + " break" : minLabel(sec) + " · round \(focusRound)"
        if !paused { push(e, front: true) }
        playSound(focusBreak ? "Hero" : "Submarine")
    }

    func timerDoneAction(_ e: IslandEvent, addMinute: Bool) {
        remove(e)
        if addMinute { startTimer(60) }
    }

    // MARK: calendar

    func meetingsUpdated(_ list: [MeetingInfo]) {
        if list != meetings { meetings = list }
        guard Prefs.b(.calendar), Prefs.b(.meetingAlerts), !paused else { return }
        let now = Date()
        for m in list where !alerted.contains(m.id) {
            let lead = m.start.timeIntervalSince(now)
            if lead <= 300 && lead > -60 {
                alerted.insert(m.id)
                let e = IslandEvent(.meeting, seconds: 12)
                e.title = m.title
                e.url = m.link
                e.meetingStart = m.start
                e.accent = m.color.map { Color(nsColor: $0) } ?? Palette.purple
                push(e, front: true)
                playSound("Ping")
            }
        }
    }

    // MARK: launcher

    func parseDuration(_ q0: String) -> Int {
        var q = q0.lowercased()
        for w in ["timer", "set", "for"] { q = q.replacingOccurrences(of: w, with: "") }
        q = q.trimmingCharacters(in: .whitespaces)
        guard let first = q.first, first.isNumber else { return 0 }
        if q.contains(":") {
            let p = q.split(separator: ":")
            if p.count == 2, let m = Int(p[0]), let s = Int(p[1]), s < 60 { return m * 60 + s }
            return 0
        }
        let digits = q.prefix { $0.isNumber }
        guard let n = Int(digits), n > 0 else { return 0 }
        let unit = q.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        switch unit {
        case "", "m", "min", "mins", "minute", "minutes": return n <= 600 ? n * 60 : 0
        case "s", "sec", "secs", "second", "seconds": return n <= 36000 ? n : 0
        case "h", "hr", "hrs", "hour", "hours": return n <= 24 ? n * 3600 : 0
        default: return 0
        }
    }

    func search() {
        var r: [LaunchResult] = []
        selection = 0
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { if !results.isEmpty { results = [] }; return }
        let d = parseDuration(q)
        if d > 0 { r.append(LaunchResult(kind: .timer, name: "Start a \(minLabel(d)) timer", seconds: d)) }
        if "focus".hasPrefix(q) || q == "pomodoro" {
            r.append(LaunchResult(kind: .focus, name: focus.on ? "Stop focus" : "Start focus · \(Prefs.i(.focusMin)) min"))
        }
        if q.count >= 3 && "islet settings".contains(q) { r.append(LaunchResult(kind: .settings, name: "Islet Settings")) }
        let scored = apps.compactMap { a -> (Int, AppEntry)? in
            guard let rng = a.lower.range(of: q) else { return nil }
            let pos = a.lower.distance(from: a.lower.startIndex, to: rng.lowerBound)
            var tier = 2
            if pos == 0 { tier = 0 } else {
                let prev = a.lower[a.lower.index(before: rng.lowerBound)]
                if prev == " " || prev == "-" { tier = 1 }
            }
            return (tier * 1000 + a.lower.count, a)
        }.sorted { $0.0 < $1.0 }
        for (_, a) in scored.prefix(max(0, 7 - r.count)) { r.append(LaunchResult(kind: .app, name: a.name, path: a.path)) }
        results = r
    }

    func run(_ r: LaunchResult) {
        collapse()
        switch r.kind {
        case .app:
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: r.path), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        case .timer: startTimer(r.seconds)
        case .focus: if focus.on { stopFocus() } else { startFocus() }
        case .settings: onOpenSettings?()
        }
    }

    func runSelection() { if selection < results.count { run(results[selection]) } }
    func moveSelection(_ d: Int) { if !results.isEmpty { selection = (selection + d + results.count) % results.count } }

    var pinnedApps: [AppEntry] {
        let ids = Prefs.s(.pinned).split(separator: "|").map(String.init)
        if !ids.isEmpty { return ids.compactMap { id in apps.first { $0.path == id } } }
        var out: [AppEntry] = []
        for n in ["finder", "safari", "google chrome", "arc", "spotify", "music", "messages", "whatsapp", "mail", "notes", "calendar", "system settings"] {
            if let a = apps.first(where: { $0.lower == n }) { out.append(a) }
            if out.count >= 6 { break }
        }
        return out
    }

    func togglePin(_ a: AppEntry) {
        var ids = Prefs.s(.pinned).split(separator: "|").map(String.init)
        if ids.isEmpty { ids = pinnedApps.map { $0.path } }
        if let i = ids.firstIndex(of: a.path) { ids.remove(at: i) } else { ids.insert(a.path, at: 0); if ids.count > 6 { ids = Array(ids.prefix(6)) } }
        Prefs.set(.pinned, ids.isEmpty ? "|" : ids.joined(separator: "|"))
        objectWillChange.send()
    }

    func isPinned(_ a: AppEntry) -> Bool { pinnedApps.contains(a) }

    func launch(_ a: AppEntry) {
        collapse()
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: a.path), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    func snip() {
        collapse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-i", "-U"]       // the same toolbar as ⇧⌘5
            try? p.run()
        }
    }
}
