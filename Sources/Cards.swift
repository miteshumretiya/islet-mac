import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Events (notifications, volume, screenshots, …)

struct EventView: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        switch e.kind {
        case .volume: VolumeWings(m: m)
        case .charging, .charged, .lowBattery: BatteryWings(m: m, e: e)
        default:
            VStack(spacing: 0) {
                Color.clear.frame(height: m.notch.height)
                card
            }
        }
    }

    @ViewBuilder var card: some View {
        switch e.kind {
        case .notif: NotifCard(m: m, e: e)
        case .device: DeviceCard(e: e)
        case .shot: ShotCard(m: m, e: e)
        case .file: FileCard(m: m, e: e)
        case .nowPlaying: NowPlayingCard(m: m)
        case .timerDone: TimerDoneCard(m: m, e: e)
        case .focus: SimpleCard(icon: m.focusBreak ? "cup.and.saucer.fill" : "leaf.fill", tint: m.focusBreak ? Palette.blue : Palette.green, title: e.title, sub: e.body)
        case .meeting: MeetingCard(m: m, e: e)
        case .welcome: SimpleCard(icon: "sparkles", tint: Palette.purple, title: "Islet is running", sub: "Hover the notch to peek · click it for apps & timers · ⌥Space anywhere")
        default: EmptyView()
        }
    }
}

struct VolumeWings: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let v = m.muted ? 0 : Double(m.volume)
        Wings(notch: m.notch, wing: 96) {
            Image(systemName: symbol(v)).font(.system(size: 13, weight: .semibold)).frame(width: 22)
        } right: {
            HStack(spacing: 6) {
                SliderBar(value: v, color: .white, height: 4) { nv, _ in m.audio?.setVolume(Float(nv)) }
                    .frame(width: 52)
                Text("\(Int((v * 100).rounded()))").font(.system(size: 11.5, weight: .semibold)).monospacedDigit().frame(width: 22, alignment: .trailing)
            }
        }
    }

    func symbol(_ v: Double) -> String {
        if v < 0.005 { return "speaker.slash.fill" }
        if v < 0.34 { return "speaker.wave.1.fill" }
        if v < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct BatteryWings: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        let low = e.kind == .lowBattery
        let c = low ? Palette.red : Palette.green
        Wings(notch: m.notch, wing: 84) {
            HStack(spacing: 4) {
                Image(systemName: low ? "battery.25" : "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(c)
                Text(low ? "Low" : (e.kind == .charged ? "Full" : "Charging")).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
        } right: {
            Text("\(m.battery.percent)%").font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(c)
        }
    }
}

struct AppIconView: View {
    let icon: NSImage?
    var size: CGFloat = 40
    var fallback = "bell.fill"
    var tint: Color = Palette.blue

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(tint.opacity(0.25))
                    Image(systemName: fallback).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(tint)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct NotifCard: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent
    @State var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AppIconView(icon: e.icon, size: 42, tint: e.accent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(e.app).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    Text("·").foregroundStyle(.white.opacity(0.35)).font(.system(size: 11.5))
                    Text(ago(e.date)).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.5))
                    if e.stack > 1 {
                        Text("+\(e.stack - 1)").font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                    }
                }
                Text(e.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if !e.body.isEmpty {
                    Text(e.body).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if !e.otp.isEmpty && Prefs.b(.otp) {
                OTPChip(m: m, e: e).padding(.top, 10)
            } else if hover {
                HStack(spacing: 6) {
                    IconButton(icon: "moon.zzz.fill", size: 11, box: 26, background: 0.14) { m.snooze(e) }.help("Remind me in 10 minutes")
                    IconButton(icon: "xmark", size: 11, box: 26, background: 0.14) { m.dismiss(e) }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct OTPChip: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        let copied = e.copiedAt.map { Date().timeIntervalSince($0) < 1.5 } ?? false
        Button { m.copyOTP(e) } label: {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc.fill").font(.system(size: 11, weight: .bold))
                Text(copied ? "Copied" : e.otp).font(.system(size: 14, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(Palette.green)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(Palette.green.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .help("Copy the code")
    }
}

struct DeviceCard: View {
    let e: IslandEvent

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.blue.opacity(0.22))
                Image(systemName: outputSymbol(e.title, false)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.blue)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sound output").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Text(e.title).font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 9)
    }
}

struct ShotCard: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        let copied = e.copiedAt.map { Date().timeIntervalSince($0) < 1.5 } ?? false
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let img = e.image {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                }
            }
            .frame(width: 136, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .onDrag { NSItemProvider(contentsOf: e.url) ?? NSItemProvider() }
            .help("Drag it into any app")
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(copied ? "Copied to clipboard" : "Screenshot").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(copied ? Palette.green : .white)
                    Text(e.title).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                HStack(spacing: 6) {
                    PillButton(icon: "doc.on.doc", label: "Copy") { m.copyImage(e) }
                    PillButton(icon: "pencil.tip.crop.circle", label: "Markup") { m.markup(e) }
                    PillButton(icon: "folder", label: "Show") { m.reveal(e) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct FileCard: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        HStack(spacing: 13) {
            AppIconView(icon: e.icon, size: 44, fallback: "arrow.down.doc.fill", tint: Palette.blue)
                .onDrag { NSItemProvider(contentsOf: e.url) ?? NSItemProvider() }
            VStack(alignment: .leading, spacing: 1) {
                Text("Downloaded · " + fmtBytes(e.bytes)).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Text(e.title).font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
            }
            Spacer(minLength: 8)
            PillButton(icon: nil, label: "Open", tint: Palette.blue, strong: true) {
                if let u = e.url { NSWorkspace.shared.open(u) }
                m.dismiss(e)
            }
            .frame(width: 74)
            IconButton(icon: "folder", size: 13, box: 32, background: 0.12) { m.reveal(e) }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

struct NowPlayingCard: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        HStack(spacing: 12) {
            ArtView(image: m.art, size: 44, radius: 10, tint: m.artAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text(m.np.title).font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
                Text(m.np.artist).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer()
            BeatBars(color: m.artAccent, playing: m.np.playing, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct TimerDoneCard: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Palette.orange.opacity(0.25))
                    Image(systemName: "alarm.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.orange)
                        .symbolEffect(.pulse)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timer done").font(.system(size: 16, weight: .semibold))
                    Text(e.body).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            HStack(spacing: 8) {
                PillButton(icon: "plus", label: "1 min") { m.timerDoneAction(e, addMinute: true) }
                PillButton(icon: "stop.fill", label: "Stop", tint: Palette.orange, strong: true) { m.timerDoneAction(e, addMinute: false) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
}

struct MeetingCard: View {
    @ObservedObject var m: IslandModel
    let e: IslandEvent

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(e.accent.opacity(0.25))
                Image(systemName: "calendar").font(.system(size: 18, weight: .semibold)).foregroundStyle(e.accent)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text(startsText).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Text(e.title).font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let u = e.url {
                PillButton(icon: "video.fill", label: "Join", tint: Palette.green, strong: true) {
                    NSWorkspace.shared.open(u)
                    m.dismiss(e)
                }
                .frame(width: 84)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    var startsText: String {
        guard let s = e.meetingStart else { return "Starting soon" }
        let mins = Int((s.timeIntervalSinceNow / 60).rounded())
        if mins <= 0 { return "Starting now" }
        return "In \(mins) min · " + s.formatted(date: .omitted, time: .shortened)
    }
}

struct SimpleCard: View {
    let icon: String
    let tint: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(tint.opacity(0.22))
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(sub).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

// MARK: - Launcher

struct LauncherView: View {
    @ObservedObject var m: IslandModel
    @FocusState var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: m.notch.height)
            header
            searchField.padding(.top, 10)
            if m.query.isEmpty {
                PinnedRow(m: m).padding(.top, 12)
                TilesRow(m: m).padding(.top, 8)
                RecentList(m: m).padding(.top, 12)
            } else {
                ResultsList(m: m).padding(.top, 8)
            }
        }
        .padding(.horizontal, 22)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true } }
    }

    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.clock, format: .dateTime.hour().minute()).font(.system(size: 28, weight: .semibold)).monospacedDigit()
                Text(m.clock, format: .dateTime.weekday(.wide).day().month(.wide)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if let next = m.meetings.first(where: { $0.end > Date() }) {
                MeetingChip(m: m, meeting: next)
            }
            if m.battery.present && Prefs.b(.battery) {
                BatteryGlyph(percent: m.battery.percent, charging: m.battery.onAC).padding(.leading, 8)
            }
            IconButton(icon: "gearshape.fill", size: 14, box: 32, background: 0.1) {
                m.collapse()
                m.onOpenSettings?()
            }
            .padding(.leading, 6)
        }
        .padding(.top, 10)
    }

    var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            if m.demo {
                Text(m.query.isEmpty ? "Search apps · type 10m for a timer" : m.query)
                    .font(.system(size: 14.5)).foregroundStyle(.white.opacity(m.query.isEmpty ? 0.38 : 1))
                Spacer()
            } else {
                TextField("", text: $m.query, prompt: Text("Search apps · type 10m for a timer").foregroundColor(.white.opacity(0.38)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14.5))
                    .focused($focused)
                    .onSubmit { m.runSelection() }
                    .onKeyPress(.downArrow) { m.moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { m.moveSelection(-1); return .handled }
                    .onKeyPress(.escape) {
                        if m.query.isEmpty { m.collapse() } else { m.query = "" }
                        return .handled
                    }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.09)))
    }
}

struct MeetingChip: View {
    @ObservedObject var m: IslandModel
    let meeting: MeetingInfo

    var body: some View {
        Button {
            if let u = meeting.link { NSWorkspace.shared.open(u) } else if let cal = URL(string: "ical://") { NSWorkspace.shared.open(cal) }
            m.collapse()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(meeting.color.map { Color(nsColor: $0) } ?? Palette.purple).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 0) {
                    Text(meeting.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                    Text(when).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                }
                if meeting.link != nil { Image(systemName: "video.fill").font(.system(size: 10)).foregroundStyle(Palette.green) }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: 190, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    var when: String {
        if meeting.start <= Date() { return "Now · until " + meeting.end.formatted(date: .omitted, time: .shortened) }
        return meeting.start.formatted(date: .omitted, time: .shortened)
    }
}

struct PinnedRow: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let pins = m.pinnedApps
        HStack(spacing: 0) {
            if pins.isEmpty {
                Text("Right-click an app in search results to pin it here")
                    .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, minHeight: 80)
            }
            ForEach(pins) { a in
                AppCell(m: m, app: a)
            }
            if !pins.isEmpty && pins.count < 6 { Spacer(minLength: 0) }
        }
        .frame(height: 82)
    }
}

struct AppCell: View {
    @ObservedObject var m: IslandModel
    let app: AppEntry
    @State var hover = false

    var body: some View {
        Button { m.launch(app) } label: {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().interpolation(.high).frame(width: 42, height: 42)
                Text(app.name).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            }
            .frame(width: 84, height: 80)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(hover ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .contextMenu {
            Button(m.isPinned(app) ? "Unpin from Islet" : "Pin to Islet") { m.togglePin(app) }
        }
    }
}

struct TilesRow: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        HStack(spacing: 8) {
            Tile(icon: "leaf.fill", tint: Palette.green, title: m.focus.on ? "Stop" : "Focus",
                 sub: m.focus.on ? "focus session" : "\(Prefs.i(.focusMin)) min") {
                m.focus.on ? m.stopFocus() : m.startFocus()
                m.collapse()
            }
            Tile(icon: "timer", tint: Palette.orange, title: "Timer", sub: "5 min") { m.collapse(); m.startTimer(300) }
            Tile(icon: "timer", tint: Palette.orange, title: "Timer", sub: "15 min") { m.collapse(); m.startTimer(900) }
            Tile(icon: "camera.viewfinder", tint: Palette.purple, title: "Screenshot", sub: "⇧⌘5") { m.snip() }
        }
    }
}

struct Tile: View {
    let icon: String
    let tint: Color
    let title: String
    let sub: String
    let action: () -> Void
    @State var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(tint.opacity(0.24))
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text(sub).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(hover ? 0.12 : 0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct RecentList: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notifications").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !m.recent.isEmpty {
                    Button { m.clearRecent() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                            Text("Clear").font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 26)
            if !m.notifAccess {
                Button {
                    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(u) }
                    m.collapse()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill").foregroundStyle(Palette.orange)
                        Text("Allow Full Disk Access so Islet can show notifications").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.orange.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            }
            if m.recent.isEmpty {
                Text("You're all caught up").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.38))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            ForEach(m.recent.prefix(3)) { r in
                RecentRow(m: m, r: r)
            }
        }
    }
}

struct RecentRow: View {
    @ObservedObject var m: IslandModel
    let r: RecentNotif
    @State var hover = false

    var body: some View {
        Button { m.openRecent(r) } label: {
            HStack(spacing: 10) {
                AppIconView(icon: r.icon, size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(r.title.isEmpty ? r.app : r.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text(r.body.isEmpty ? r.app : r.body).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer()
                Text(ago(r.date)).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(hover ? 0.07 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct ResultsList: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        VStack(spacing: 0) {
            if m.results.isEmpty {
                Text("No matches").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, minHeight: 42)
            }
            ForEach(Array(m.results.enumerated()), id: \.element.id) { i, r in
                ResultRow(m: m, r: r, selected: i == m.selection)
            }
        }
    }
}

struct ResultRow: View {
    @ObservedObject var m: IslandModel
    let r: LaunchResult
    let selected: Bool

    var body: some View {
        Button { m.run(r) } label: {
            HStack(spacing: 11) {
                icon.frame(width: 28, height: 28)
                Text(r.name).font(.system(size: 13.5, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer()
                if selected { Image(systemName: "return").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.45)) }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(selected ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if r.kind == .app, let a = m.apps.first(where: { $0.path == r.path }) {
                Button(m.isPinned(a) ? "Unpin from Islet" : "Pin to Islet") { m.togglePin(a) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: a.path)]) }
            }
        }
    }

    @ViewBuilder var icon: some View {
        switch r.kind {
        case .app: Image(nsImage: NSWorkspace.shared.icon(forFile: r.path)).resizable().interpolation(.high)
        case .timer: SymbolTile(name: "timer", tint: Palette.orange)
        case .focus: SymbolTile(name: "leaf.fill", tint: Palette.green)
        case .settings: SymbolTile(name: "gearshape.fill", tint: .gray)
        }
    }
}

struct SymbolTile: View {
    let name: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.25))
            Image(systemName: name).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
        }
    }
}
