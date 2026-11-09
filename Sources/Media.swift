import AppKit

struct NowPlaying: Equatable {
    var title = "", artist = "", album = ""
    var duration: Double = 0, elapsed: Double = 0, rate: Double = 1
    var timestamp = Date()
    var playing = false
    var bundle = ""
    var artId = ""

    var has: Bool { !title.isEmpty }

    func position(at now: Date = Date()) -> Double {
        var p = elapsed
        if playing { p += now.timeIntervalSince(timestamp) * (rate > 0 ? rate : 1) }
        p = max(0, p)
        return duration > 0 ? min(p, duration) : p
    }
}

enum MediaCommand: String { case toggle, play, pause, next, prev }

/// Reads "Now Playing" for every app (Spotify, Music, Safari/Chrome videos, Podcasts…) through the
/// system's MediaRemote service via the perl bridge, and falls back to asking Spotify / Music directly.
final class MediaSource {
    var onUpdate: ((NowPlaying, NSImage?) -> Void)?

    private var proc: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var restarts = 0
    private var gotHello = false
    private var everTitle = false
    private var started = Date()
    private var current = NowPlaying()
    private var art: NSImage?
    private var fallbackTimer: Timer?
    private var useScripts = false
    private var stopping = false

    func start() {
        started = Date()
        launch()
        // If the bridge stays silent while Spotify or Music is playing, ask those apps directly.
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.fallbackTick() }
    }

    func stop() {
        stopping = true
        proc?.terminate()
    }

    func send(_ c: MediaCommand) {
        if useScripts { ScriptPlayer.command(c, bundle: current.bundle); return }
        write(c.rawValue)
        // optimistic update so the play/pause button flips instantly
        if c == .toggle || c == .play || c == .pause {
            var n = current
            n.elapsed = n.position()
            n.timestamp = Date()
            n.playing = c == .toggle ? !n.playing : c == .play
            current = n
            onUpdate?(n, art)
        }
    }

    func seek(_ seconds: Double) {
        if useScripts { ScriptPlayer.seek(seconds, bundle: current.bundle); return }
        write(String(format: "seek %.2f", seconds))
        var n = current
        n.elapsed = seconds
        n.timestamp = Date()
        current = n
        onUpdate?(n, art)
    }

    private func write(_ s: String) {
        guard let input, let d = (s + "\n").data(using: .utf8) else { return }
        input.write(d)
    }

    private func launch() {
        guard !stopping, let res = Bundle.main.resourceURL else { return }
        let script = res.appendingPathComponent("mediaremote.pl").path
        let lib = res.appendingPathComponent("libIsletMediaRemote.dylib").path
        guard FileManager.default.fileExists(atPath: lib) else { return }
        // A downloaded app keeps the "quarantine" mark; perl would refuse to load a quarantined library.
        for p in [script, lib] { removexattr(p, "com.apple.quarantine", 0) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [script, lib, "islet_stream"]
        let out = Pipe(), inp = Pipe()
        p.standardOutput = out
        p.standardInput = inp
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if d.isEmpty { h.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.consume(d) }
        }
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.stopping else { return }
                self.restarts += 1
                self.input = nil
                let delay = min(60.0, 2.0 * Double(self.restarts))
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.launch() }
            }
        }
        do {
            try p.run()
            proc = p
            input = inp.fileHandleForWriting
        } catch {
            NSLog("Islet: media bridge failed: \(error)")
        }
    }

    private func consume(_ d: Data) {
        buffer.append(d)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] { handle(obj) }
        }
    }

    private func handle(_ o: [String: Any]) {
        if o["hello"] != nil { gotHello = true; restarts = 0; return }
        if o["error"] != nil { return }
        var n = NowPlaying()
        n.title = o["title"] as? String ?? ""
        n.artist = o["artist"] as? String ?? ""
        n.album = o["album"] as? String ?? ""
        n.duration = (o["duration"] as? NSNumber)?.doubleValue ?? 0
        n.elapsed = (o["elapsed"] as? NSNumber)?.doubleValue ?? 0
        n.rate = (o["rate"] as? NSNumber)?.doubleValue ?? 1
        n.playing = (o["playing"] as? NSNumber)?.boolValue ?? false
        if let ts = (o["timestamp"] as? NSNumber)?.doubleValue { n.timestamp = Date(timeIntervalSince1970: ts) }
        n.bundle = (o["parent"] as? String) ?? (o["bundle"] as? String) ?? ""
        n.artId = o["artId"] as? String ?? ""
        if let b64 = o["art"] as? String, let data = Data(base64Encoded: b64) { art = NSImage(data: data) }
        if n.artId.isEmpty { art = nil }
        if n.has { everTitle = true; if useScripts { useScripts = false } }
        if useScripts { return }
        current = n
        onUpdate?(n, art)
    }

    private func fallbackTick() {
        let running = ScriptPlayer.runningPlayer()
        if !useScripts {
            let silent = !gotHello || !everTitle
            guard silent, running != nil, Date().timeIntervalSince(started) > 12 else { return }
            useScripts = true
        }
        guard let bundle = running, let r = ScriptPlayer.read(bundle) else {
            if current.has { current = NowPlaying(); art = nil; onUpdate?(current, nil) }
            return
        }
        if r.np.title != current.title { art = nil; if let u = r.artURL { loadArt(u, for: r.np.title) } }
        current = r.np
        onUpdate?(current, art)
    }

    private func loadArt(_ url: URL, for title: String) {
        URLSession.shared.dataTask(with: url) { [weak self] d, _, _ in
            guard let d, let img = NSImage(data: d) else { return }
            DispatchQueue.main.async {
                guard let self, self.current.title == title else { return }
                self.art = img
                self.onUpdate?(self.current, img)
            }
        }.resume()
    }
}

/// Spotify and Music answer AppleScript; used only if the Now Playing bridge doesn't work on this Mac.
enum ScriptPlayer {
    static let spotify = "com.spotify.client", music = "com.apple.Music"

    static func runningPlayer() -> String? {
        let apps = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        if apps.contains(spotify) { return spotify }
        if apps.contains(music) { return music }
        return nil
    }

    private static func run(_ src: String) -> String? {
        var err: NSDictionary?
        guard let s = NSAppleScript(source: src) else { return nil }
        let r = s.executeAndReturnError(&err)
        return err == nil ? r.stringValue : nil
    }

    static func read(_ bundle: String) -> (np: NowPlaying, artURL: URL?)? {
        let app = bundle == spotify ? "Spotify" : "Music"
        let durExpr = bundle == spotify ? "((duration of t) / 1000)" : "(duration of t)"
        let artExpr = bundle == spotify ? "(artwork url of t)" : "\"\""
        let src = """
        tell application "\(app)"
            if player state is stopped then return ""
            set t to current track
            return (player state as string) & "|#|" & (name of t) & "|#|" & (artist of t) & "|#|" & (album of t) & "|#|" & \(durExpr) & "|#|" & player position & "|#|" & \(artExpr)
        end tell
        """
        guard let out = run(src), !out.isEmpty else { return nil }
        let f = out.components(separatedBy: "|#|")
        guard f.count >= 7 else { return nil }
        func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        var n = NowPlaying()
        n.playing = f[0] == "playing"
        n.title = f[1]; n.artist = f[2]; n.album = f[3]
        n.duration = num(f[4]); n.elapsed = num(f[5]); n.timestamp = Date()
        n.bundle = bundle
        return (n, URL(string: f[6]))
    }

    static func command(_ c: MediaCommand, bundle: String) {
        let app = bundle == spotify ? "Spotify" : "Music"
        let verb: String
        switch c {
        case .toggle: verb = "playpause"
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .next: verb = "next track"
        case .prev: verb = "previous track"
        }
        _ = run("tell application \"\(app)\" to \(verb)")
    }

    static func seek(_ s: Double, bundle: String) {
        let app = bundle == spotify ? "Spotify" : "Music"
        _ = run("tell application \"\(app)\" to set player position to \(Int(s))")
    }
}
