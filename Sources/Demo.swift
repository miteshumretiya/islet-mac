import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sample content: used by `--gallery out.png` (a picture of every state) and `--demo N` (show state N live).
enum Demo {
    static let titles = [
        "Idle — the island is the notch", "Pointer on the notch — peek",
        "Music + timer (tap the bubble to switch)", "Music — expanded",
        "Notification with a one-time code", "Messages, stacked",
        "Volume", "Charging",
        "Screenshot — copy, mark up or drag it out", "Download finished",
        "Focus session — expanded", "On a call",
        "Meeting in 5 minutes", "AirPods connected",
        "Launcher — click the notch or ⌥Space", "Launcher — type 10m for a timer",
    ]

    static func art() -> NSImage {
        NSImage(size: NSSize(width: 160, height: 160), flipped: false) { r in
            let g = NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.37, blue: 0.49, alpha: 1),
                                        NSColor(calibratedRed: 0.42, green: 0.24, blue: 0.91, alpha: 1)])
            g?.draw(in: r, angle: -45)
            NSColor(white: 1, alpha: 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: 70, y: 62, width: 64, height: 64)).fill()
            return true
        }
    }

    static func screenshot() -> NSImage {
        NSImage(size: NSSize(width: 320, height: 200), flipped: true) { r in
            NSColor(calibratedWhite: 0.95, alpha: 1).setFill(); r.fill()
            NSColor(calibratedWhite: 0.17, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 320, height: 26).fill()
            NSColor(calibratedWhite: 0.88, alpha: 1).setFill(); NSRect(x: 0, y: 26, width: 70, height: 174).fill()
            NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
            for i in 0..<6 { NSRect(x: 86, y: 40 + i * 14, width: 120 + (i % 3) * 40, height: 6).fill() }
            NSGradient(colors: [NSColor.systemPurple, NSColor.systemTeal])?.draw(in: NSRect(x: 86, y: 130, width: 150, height: 54), angle: 0)
            return true
        }
    }

    static func icon(_ bundle: String, _ fallbackPath: String) -> NSImage? {
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) { return NSWorkspace.shared.icon(forFile: u.path) }
        if FileManager.default.fileExists(atPath: fallbackPath) { return NSWorkspace.shared.icon(forFile: fallbackPath) }
        return nil
    }

    static func reset(_ m: IslandModel) {
        m.events = []; m.expanded = nil; m.launcherOpen = false; m.query = ""; m.peek = false
        m.timer = Countdown(); m.focus = Countdown(); m.downloads = [:]; m.micInUse = false; m.cameraInUse = false
        m.np = NowPlaying(); m.preferAct = nil; m.unseen = 0
    }

    static func music(_ m: IslandModel, playing: Bool = true) {
        var n = NowPlaying()
        n.title = "Midnight Drive"; n.artist = "The Night Owls"; n.album = "Neon"
        n.duration = 214; n.elapsed = 83; n.playing = playing; n.timestamp = Date(); n.bundle = "com.spotify.client"; n.artId = "demo"
        m.np = n
        m.art = art()
        m.artAccent = Color(nsColor: accentColor(m.art) ?? .systemPink)
    }

    static func scene(_ i: Int, _ m: IslandModel) {
        m.demo = true
        reset(m)
        m.battery = BatteryState(present: true, percent: 82, onAC: false, charging: false, charged: false, minutesToFull: -1, minutesToEmpty: 300)
        m.outputName = "MacBook Pro Speakers"
        switch i {
        case 1: m.peek = true; m.unseen = 2
        case 2:
            music(m)
            m.timer = Countdown(on: true, paused: true, endAt: Date(), left: 312, total: 600)
            m.preferAct = .music
        case 3: music(m); m.expanded = .music; m.outputName = "AirPods Pro"; m.outputBT = true
        case 4:
            let e = IslandEvent(.notif, seconds: 12)
            e.app = "Messages"; e.bundle = "com.apple.MobileSMS"; e.title = "HDFC Bank"
            e.body = "482913 is your OTP for a payment of Rs 1,250 at Amazon. Do not share it with anyone."
            e.otp = findOTP(e.title, e.body) ?? ""
            e.icon = icon("com.apple.MobileSMS", "/System/Applications/Messages.app"); e.accent = Palette.green
            m.events = [e]
        case 5:
            let e = IslandEvent(.notif, seconds: 6)
            e.app = "WhatsApp"; e.bundle = "net.whatsapp.WhatsApp"; e.title = "Priya"
            e.body = "Are we still on for dinner tonight? I booked the table for 8 🍽️"; e.stack = 3
            e.icon = icon("net.whatsapp.WhatsApp", "/System/Applications/Messages.app"); e.accent = Palette.green
            m.events = [e]
        case 6: m.volume = 0.62; m.events = [IslandEvent(.volume, seconds: 2)]
        case 7:
            m.battery = BatteryState(present: true, percent: 82, onAC: true, charging: true, charged: false, minutesToFull: 34, minutesToEmpty: -1)
            let e = IslandEvent(.charging, seconds: 4); e.value = 82; e.accent = Palette.green
            m.events = [e]
        case 8:
            let e = IslandEvent(.shot, seconds: 6)
            e.title = "Screenshot 2026-11-09 at 21.42.10.png"; e.image = screenshot(); e.accent = Palette.purple
            e.url = URL(fileURLWithPath: "/tmp/demo.png")
            m.events = [e]
        case 9:
            let e = IslandEvent(.file, seconds: 5)
            e.title = "Quarterly-report.pdf"; e.bytes = 2_480_000; e.icon = NSWorkspace.shared.icon(for: .pdf)
            e.url = URL(fileURLWithPath: "/tmp/Quarterly-report.pdf")
            m.events = [e]
        case 10:
            m.focus = Countdown(on: true, paused: true, endAt: Date(), left: 1093, total: 1500)
            m.focusRound = 2
            m.expanded = .focus
        case 11:
            m.micInUse = true; m.cameraInUse = true; m.callSince = Date().addingTimeInterval(-754)
        case 12:
            let e = IslandEvent(.meeting, seconds: 12)
            e.title = "Design review"; e.meetingStart = Date().addingTimeInterval(300); e.url = URL(string: "https://meet.google.com/abc-defg-hij")
            e.accent = Palette.purple
            m.events = [e]
        case 13:
            let e = IslandEvent(.device, seconds: 3); e.title = "AirPods Pro"; e.accent = Palette.blue
            m.events = [e]
        case 14:
            m.launcherOpen = true
            m.recent = [
                RecentNotif(app: "WhatsApp", bundle: "net.whatsapp.WhatsApp", title: "Priya", body: "Are we still on for dinner tonight?",
                            icon: icon("net.whatsapp.WhatsApp", "/System/Applications/Messages.app"), date: Date().addingTimeInterval(-120)),
                RecentNotif(app: "Mail", bundle: "com.apple.mail", title: "Weekly sync moved to 3 PM", body: "Rahul Mehta",
                            icon: icon("com.apple.mail", "/System/Applications/Mail.app"), date: Date().addingTimeInterval(-1500)),
            ]
            m.notifAccess = true
            m.meetings = [MeetingInfo(id: "d", title: "Design review", start: Date().addingTimeInterval(1800), end: Date().addingTimeInterval(5400),
                                      link: URL(string: "https://meet.google.com/x"), color: .systemPurple)]
        case 15:
            m.launcherOpen = true
            m.notifAccess = true
            m.query = "10m"
        default: break
        }
        if m.apps.isEmpty { m.apps = AppCatalog.load() }
        m.refresh()
    }

    /// Live demo inside the running app (used for screenshots on the build machine).
    static func fill(_ m: IslandModel) {
        let args = CommandLine.arguments
        var n = 4
        if let i = args.firstIndex(of: "--demo"), i + 1 < args.count, let v = Int(args[i + 1]) { n = v }
        scene(n, m)
        m.demo = false
        if case .event = m.mode { m.events.first?.remain = 600 }
    }
}

// MARK: - Gallery picture

struct GalleryCell: View {
    @ObservedObject var m: IslandModel
    let title: String
    let index: Int

    var body: some View {
        let h = max(120, m.size(m.mode).height + 74)
        ZStack(alignment: .top) {
            LinearGradient(colors: [wallTop, Color(hex: 0x10111A)], startPoint: .top, endPoint: .bottom)
            HStack(spacing: 14) {
                Image(systemName: "apple.logo").font(.system(size: 13, weight: .semibold))
                Text("Finder").font(.system(size: 13, weight: .bold))
                Text("File   Edit   View").font(.system(size: 13))
                Spacer()
                Image(systemName: "wifi").font(.system(size: 12))
                Text("Mon 9 Nov  21:42").font(.system(size: 13))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(height: m.notch.height)
            .background(Color.black.opacity(0.18))
            IslandRoot(m: m)
            VStack {
                Spacer()
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 12)
            }
        }
        .frame(width: 760, height: h, alignment: .top)
        .clipped()
    }

    var wallTop: Color {
        [Color(hex: 0x2B3A67), Color(hex: 0x3B2A4F), Color(hex: 0x1F4E5A), Color(hex: 0x4A3B2A)][index % 4]
    }
}

struct GalleryView: View {
    let models: [IslandModel]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<((models.count + 1) / 2), id: \.self) { r in
                HStack(alignment: .top, spacing: 6) {
                    ForEach(0..<2, id: \.self) { c in
                        let i = r * 2 + c
                        if i < models.count { GalleryCell(m: models[i], title: Demo.titles[i], index: i) }
                    }
                }
            }
        }
        .padding(6)
        .background(Color(hex: 0x0B0B0F))
        .environment(\.colorScheme, .dark)
    }
}

enum Gallery {
    static func render(to path: String) -> Bool {
        Prefs.register()
        var models: [IslandModel] = []
        for i in 0..<Demo.titles.count {
            let m = IslandModel()
            m.notch = CGSize(width: 200, height: 37)
            m.hasNotch = true
            Demo.scene(i, m)
            models.append(m)
        }
        return MainActor.assumeIsolated {
            let r = ImageRenderer(content: GalleryView(models: models))
            r.scale = 1.5
            guard let cg = r.cgImage else { return false }
            let rep = NSBitmapImageRep(cgImage: cg)
            guard let data = rep.representation(using: .png, properties: [:]) else { return false }
            return (try? data.write(to: URL(fileURLWithPath: path))) != nil
        }
    }
}
