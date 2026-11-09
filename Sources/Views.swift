import SwiftUI
import AppKit

// MARK: - Shapes

/// The island: flat top flush with the screen edge, small concave "ears" that flare into the top edge
/// (like the hardware notch), and rounded bottom corners.
struct NotchShape: Shape {
    var ear: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(ear, bottom) }
        set { ear = newValue.first; bottom = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let e = min(ear, r.width / 4, r.height / 2)
        let b = max(0, min(bottom, r.height - e, (r.width - 2 * e) / 2))
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + e, y: r.minY + e), control: CGPoint(x: r.minX + e, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + e, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + e + b, y: r.maxY), control: CGPoint(x: r.minX + e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - e, y: r.maxY - b), control: CGPoint(x: r.maxX - e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY + e))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - e, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct GlowView: View {
    let size: CGSize
    let ear: CGFloat
    let bottom: CGFloat
    let colors: [Color]
    let level: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let angle = Angle.degrees(ctx.date.timeIntervalSinceReferenceDate * 40)
            let grad = AngularGradient(gradient: Gradient(colors: colors + [colors.first ?? .white]), center: .center, angle: angle)
            ZStack {
                NotchShape(ear: ear, bottom: bottom).stroke(grad, lineWidth: 7).blur(radius: 12).opacity(0.9)
                NotchShape(ear: ear, bottom: bottom).stroke(grad, lineWidth: 2.5).blur(radius: 2.5).opacity(0.85)
            }
            .frame(width: size.width, height: size.height)
        }
        .opacity(level)
        .allowsHitTesting(false)
    }
}

// MARK: - Root

struct IslandRoot: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let s = m.size(m.mode)
        let ear = m.ear(m.mode)
        let bottom = m.bottomRadius(m.mode)
        ZStack(alignment: .top) {
            if m.glowLevel > 0.01 {
                GlowView(size: s, ear: ear, bottom: bottom, colors: m.glowColors, level: m.glowLevel)
                    .transition(.opacity)
            }
            IslandBody(m: m, size: s, ear: ear, bottom: bottom)
            if let b = m.bubbleAct {
                BubbleView(m: m, act: b)
                    .frame(width: m.notch.height, height: m.notch.height)
                    .offset(x: s.width / 2 + 7 + m.notch.height / 2 - 7)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(width: IslandModel.panelSize.width, height: IslandModel.panelSize.height, alignment: .top)
        .opacity(m.mode == .hidden && !m.hasNotch ? 0 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: m.mode)
        .animation(.spring(response: 0.42, dampingFraction: 0.75), value: m.bubbleAct)
        .animation(.easeInOut(duration: 0.45), value: m.glowLevel)
        .environment(\.colorScheme, .dark)
    }
}

struct IslandBody: View {
    @ObservedObject var m: IslandModel
    let size: CGSize
    let ear: CGFloat
    let bottom: CGFloat

    var body: some View {
        let shape = NotchShape(ear: ear, bottom: bottom)
        ZStack(alignment: .top) {
            shape.fill(Color.black)
            ModeContent(m: m, mode: m.mode)
                .id(contentKey)
                .transition(.asymmetric(
                    insertion: AnyTransition.opacity.combined(with: .scale(scale: 0.92, anchor: .top)).animation(.easeOut(duration: 0.26).delay(0.07)),
                    removal: AnyTransition.opacity.animation(.easeIn(duration: 0.1))))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { m.tapBody() }
        .scaleEffect(m.pressing ? 0.97 : 1, anchor: .top)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: m.pressing)
    }

    var contentKey: String {
        switch m.mode {
        case .hidden: return "hidden"
        case .idle: return "idle"
        case .peek: return "peek"
        case .compact(let a): return "c\(a.rawValue)"
        case .expanded(let a): return "x\(a.rawValue)"
        case .event(let id): return id.uuidString
        case .launcher: return "launcher"
        }
    }
}

struct ModeContent: View {
    @ObservedObject var m: IslandModel
    let mode: Mode

    var body: some View {
        let s = m.size(mode)
        Group {
            switch mode {
            case .hidden, .idle:
                Color.clear
            case .peek:
                PeekView(m: m)
            case .compact(let a):
                CompactView(m: m, act: a)
            case .expanded(let a):
                ExpandedView(m: m, act: a)
            case .event(let id):
                if let e = m.event(id) { EventView(m: m, e: e) } else { Color.clear }
            case .launcher:
                LauncherView(m: m)
            }
        }
        .frame(width: s.width, height: s.height, alignment: .top)
        .foregroundStyle(.white)
    }
}

// MARK: - Building blocks

/// Content to the left and right of the notch, at the notch's height.
struct Wings<L: View, R: View>: View {
    let notch: CGSize
    let wing: CGFloat
    let left: L
    let right: R

    init(notch: CGSize, wing: CGFloat, @ViewBuilder left: () -> L, @ViewBuilder right: () -> R) {
        self.notch = notch
        self.wing = wing
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: wing - 6, alignment: .leading).padding(.leading, 6)
            Color.clear.frame(width: notch.width)
            right.frame(width: wing - 6, alignment: .trailing).padding(.trailing, 6)
        }
        .frame(height: notch.height)
        .padding(.horizontal, 7)
    }
}

struct ArtView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat
    var tint: Color = Palette.pink

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.42, weight: .semibold))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct BeatBars: View {
    let color: Color
    let playing: Bool
    var height: CGFloat = 15

    private static let freq: [Double] = [7.3, 9.1, 6.2, 8.4]
    private static let phase: [Double] = [0.3, 1.7, 2.9, 4.1]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(i, t))
                }
            }
            .frame(height: height)
        }
    }

    private func barHeight(_ i: Int, _ t: Double) -> CGFloat {
        guard playing else { return 3 }
        let v = 0.5 + 0.5 * sin(t * Self.freq[i] + Self.phase[i])
        return max(3, height * CGFloat(0.28 + 0.72 * v))
    }
}

struct Ring: View {
    let progress: Double
    let color: Color
    var line: CGFloat = 2.6
    var spinning = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: line)
            if spinning {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    Circle().trim(from: 0, to: 0.3)
                        .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .rotationEffect(.degrees(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360))
                }
            } else {
                Circle().trim(from: 0, to: CGFloat(clamp(progress, 0, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct PillButton: View {
    let icon: String?
    let label: String
    var tint: Color = .white
    var strong = false
    let action: () -> Void
    @State var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                if !label.isEmpty { Text(label).font(.system(size: 12.5, weight: .semibold)) }
            }
            .foregroundStyle(tint == .white ? Color.white : tint)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(Capsule().fill((tint == .white ? Color.white : tint).opacity((strong ? 0.26 : 0.13) + (hover ? 0.08 : 0))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct IconButton: View {
    let icon: String
    var size: CGFloat = 20
    var box: CGFloat = 38
    var background: Double = 0
    var enabled = true
    let action: () -> Void
    @State var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .frame(width: box, height: box)
                .background(Circle().fill(Color.white.opacity(background + (hover && enabled ? 0.12 : 0))))
                .contentShape(Circle())
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .disabled(!enabled)
    }
}

/// A thin bar you can click or drag.
struct SliderBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 5
    let onChange: (Double, Bool) -> Void          // value, finished
    @State var drag: Double?
    @State var hover = false

    var body: some View {
        GeometryReader { g in
            let v = clamp(drag ?? value, 0, 1)
            let h = hover || drag != nil ? height + 2 : height
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16)).frame(height: h)
                Capsule().fill(color).frame(width: max(h, g.size.width * CGFloat(v)), height: h)
                if hover || drag != nil {
                    Circle().fill(Color.white).frame(width: h + 6, height: h + 6)
                        .offset(x: g.size.width * CGFloat(v) - (h + 6) / 2)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { d in
                    let nv = clamp(Double(d.location.x / max(1, g.size.width)), 0, 1)
                    drag = nv
                    onChange(nv, false)
                }
                .onEnded { d in
                    let nv = clamp(Double(d.location.x / max(1, g.size.width)), 0, 1)
                    drag = nil
                    onChange(nv, true)
                })
        }
        .frame(height: 16)
        .onHover { hover = $0 }
    }
}

// MARK: - Peek (hovering the notch while idle)

struct PeekView: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        Wings(notch: m.notch, wing: 92) {
            Text(m.clock, format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .semibold)).monospacedDigit()
        } right: {
            HStack(spacing: 6) {
                if m.unseen > 0 && Prefs.b(.missedDot) { Circle().fill(Palette.red).frame(width: 6, height: 6) }
                if m.battery.present && Prefs.b(.battery) {
                    BatteryGlyph(percent: m.battery.percent, charging: m.battery.onAC)
                } else {
                    Text(m.clock, format: .dateTime.weekday(.abbreviated).day())
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

struct BatteryGlyph: View {
    let percent: Int
    let charging: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("\(percent)%").font(.system(size: 11.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(charging ? Palette.green : (percent <= 20 ? Palette.red : .white.opacity(0.85)))
            Image(systemName: charging ? "battery.100.bolt" : symbol)
                .font(.system(size: 14))
                .foregroundStyle(charging ? Palette.green : (percent <= 20 ? Palette.red : .white.opacity(0.85)))
        }
    }

    var symbol: String {
        switch percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

// MARK: - Compact activities

struct CompactView: View {
    @ObservedObject var m: IslandModel
    let act: Act

    var body: some View {
        let c = m.color(act)
        Wings(notch: m.notch, wing: m.wing(act)) {
            left(c)
        } right: {
            right(c)
        }
    }

    @ViewBuilder func left(_ c: Color) -> some View {
        switch act {
        case .music:
            ArtView(image: m.art, size: 22, radius: 6, tint: m.artAccent)
        case .call:
            HStack(spacing: 5) {
                Image(systemName: m.micMuted ? "mic.slash.fill" : "mic.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(c)
                if m.cameraInUse { Image(systemName: "video.fill").font(.system(size: 11)).foregroundStyle(Palette.green) }
            }
        case .focus:
            HStack(spacing: 5) {
                Image(systemName: m.focusBreak ? "cup.and.saucer.fill" : "leaf.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(c)
                Text(m.focusBreak ? "Break" : "Focus").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75))
            }
        case .timer:
            Image(systemName: "timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(c)
        case .download:
            Image(systemName: "arrow.down.circle.fill").font(.system(size: 15)).foregroundStyle(c)
        case .charging:
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(c)
                Text("\(m.battery.percent)%").font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(c)
            }
        }
    }

    @ViewBuilder func right(_ c: Color) -> some View {
        switch act {
        case .music:
            BeatBars(color: c, playing: m.np.playing)
        case .call:
            Text(fmtDur(m.clock.timeIntervalSince(m.callSince))).font(.system(size: 12.5, weight: .semibold)).monospacedDigit().foregroundStyle(c)
        case .focus:
            countdown(m.focus, c)
        case .timer:
            countdown(m.timer, c)
        case .download:
            if let d = m.currentDownload {
                Ring(progress: d.fraction, color: c, spinning: d.fraction < 0).frame(width: 15, height: 15)
            }
        case .charging:
            Image(systemName: "battery.100.bolt").font(.system(size: 15)).foregroundStyle(c)
        }
    }

    func countdown(_ cd: Countdown, _ c: Color) -> some View {
        let _ = m.clock
        return Text(fmtDur(cd.remaining + 0.999)).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(c)
    }
}

struct BubbleView: View {
    @ObservedObject var m: IslandModel
    let act: Act

    var body: some View {
        let c = m.color(act)
        ZStack {
            Circle().fill(Color.black)
            Group {
                switch act {
                case .music: ArtView(image: m.art, size: m.notch.height - 12, radius: (m.notch.height - 12) / 2, tint: m.artAccent)
                case .timer: ZStack { Ring(progress: m.timer.progress, color: c); Image(systemName: "timer").font(.system(size: 9, weight: .bold)).foregroundStyle(c) }.padding(7)
                case .focus: ZStack { Ring(progress: m.focus.progress, color: c); Image(systemName: "leaf.fill").font(.system(size: 9)).foregroundStyle(c) }.padding(7)
                case .download: Ring(progress: m.currentDownload?.fraction ?? -1, color: c, spinning: (m.currentDownload?.fraction ?? -1) < 0).padding(8)
                case .call: Image(systemName: "mic.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(c)
                case .charging: Image(systemName: "bolt.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(c)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture { m.tapBubble() }
    }
}

// MARK: - Expanded activities

struct ExpandedView: View {
    @ObservedObject var m: IslandModel
    let act: Act

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: m.notch.height)
            switch act {
            case .music: MusicCard(m: m)
            case .timer: TimerCard(m: m, isFocus: false)
            case .focus: TimerCard(m: m, isFocus: true)
            case .call: CallCard(m: m)
            case .download: DownloadCard(m: m)
            case .charging: ChargingCard(m: m)
            }
        }
    }
}

struct MusicCard: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ArtView(image: m.art, size: 66, radius: 15, tint: m.artAccent)
                    .onTapGesture { m.openPlayer() }
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.np.title.isEmpty ? "Not playing" : m.np.title).font(.system(size: 15.5, weight: .semibold)).lineLimit(1)
                    Text(m.np.artist).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    OutputChip(m: m).padding(.top, 3)
                }
                Spacer(minLength: 0)
                BeatBars(color: m.artAccent, playing: m.np.playing, height: 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            ScrubRow(m: m).padding(.horizontal, 24).padding(.top, 12)
            HStack(spacing: 30) {
                IconButton(icon: "backward.fill", size: 19) { m.mediaCommand(.prev) }
                IconButton(icon: m.np.playing ? "pause.fill" : "play.fill", size: 26, box: 46) { m.mediaCommand(.toggle) }
                IconButton(icon: "forward.fill", size: 19) { m.mediaCommand(.next) }
            }
            .padding(.top, 4)
        }
    }
}

struct OutputChip: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let name = m.outputName.isEmpty ? "Speakers" : m.outputName
        Button {
            if let u = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") { NSWorkspace.shared.open(u) }
            m.collapse()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: outputSymbol(name, m.outputBT)).font(.system(size: 10.5, weight: .semibold))
                Text(name).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

func outputSymbol(_ name: String, _ bt: Bool) -> String {
    let l = name.lowercased()
    if l.contains("airpods max") { return "airpodsmax" }
    if l.contains("airpods pro") { return "airpodspro" }
    if l.contains("airpods") { return "airpods" }
    if l.contains("beats") || l.contains("headphone") || l.contains("headset") || l.contains("buds") || bt { return "headphones" }
    if l.contains("display") || l.contains("hdmi") || l.contains("tv") { return "tv" }
    if l.contains("homepod") { return "homepod.fill" }
    return "hifispeaker.fill"
}

struct ScrubRow: View {
    @ObservedObject var m: IslandModel
    @State var dragPos: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let pos = dragPos.map { $0 * m.np.duration } ?? m.np.position(at: ctx.date)
            HStack(spacing: 10) {
                Text(fmtDur(pos)).font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(.white.opacity(0.55)).frame(width: 40, alignment: .leading)
                if m.np.duration > 0 {
                    SliderBar(value: pos / max(1, m.np.duration), color: m.artAccent) { v, done in
                        if done { dragPos = nil; m.seek(v) } else { dragPos = v }
                    }
                } else {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 5)
                }
                Text(m.np.duration > 0 ? "-" + fmtDur(m.np.duration - pos) : "").font(.system(size: 11, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55)).frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct TimerCard: View {
    @ObservedObject var m: IslandModel
    let isFocus: Bool

    var body: some View {
        let cd = isFocus ? m.focus : m.timer
        let c = isFocus ? (m.focusBreak ? Palette.blue : Palette.green) : Palette.orange
        let _ = m.clock
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label(cd)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    Text(fmtDur(cd.remaining + 0.999)).font(.system(size: 42, weight: .semibold)).monospacedDigit()
                }
                Spacer()
                ZStack {
                    Ring(progress: cd.progress, color: c, line: 5.5)
                    Image(systemName: cd.paused ? "pause.fill" : (isFocus ? (m.focusBreak ? "cup.and.saucer.fill" : "leaf.fill") : "timer"))
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(c)
                }
                .frame(width: 58, height: 58)
            }
            HStack(spacing: 8) {
                PillButton(icon: cd.paused ? "play.fill" : "pause.fill", label: cd.paused ? "Resume" : "Pause") { m.togglePause(isFocus ? .focus : .timer) }
                if isFocus {
                    PillButton(icon: "forward.end.fill", label: "Skip") { m.focusNext() }
                } else {
                    PillButton(icon: "plus", label: "1 min") { m.addMinute() }
                }
                PillButton(icon: "stop.fill", label: "Stop", tint: Palette.red) { isFocus ? m.stopFocus() : m.stopTimer() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    func label(_ cd: Countdown) -> String {
        var s = isFocus ? (m.focusBreak ? "Break" : "Focus · round \(m.focusRound)") : "Timer · " + minLabel(cd.total)
        if cd.paused { s += " · paused" }
        return s
    }
}

struct CallCard: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let c = m.micMuted ? Palette.red : Palette.green
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(c.opacity(0.2))
                    Image(systemName: m.micMuted ? "mic.slash.fill" : "mic.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(c)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.micMuted ? "Microphone muted" : "On a call").font(.system(size: 15.5, weight: .semibold))
                    Text(m.cameraInUse ? "Camera and microphone in use" : "Microphone in use").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text(fmtDur(m.clock.timeIntervalSince(m.callSince))).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Palette.green)
            }
            HStack(spacing: 8) {
                PillButton(icon: m.micMuted ? "mic.fill" : "mic.slash.fill", label: m.micMuted ? "Unmute" : "Mute mic", tint: m.micMuted ? Palette.green : .white) { m.toggleMic() }
                PillButton(icon: "hand.raised.fill", label: "Privacy") {
                    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") { NSWorkspace.shared.open(u) }
                    m.collapse()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
}

struct DownloadCard: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let d = m.currentDownload
        HStack(spacing: 14) {
            ZStack {
                Ring(progress: d?.fraction ?? -1, color: Palette.blue, line: 3.5, spinning: (d?.fraction ?? -1) < 0)
                Image(systemName: "arrow.down").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.blue)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloading").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Text(d?.name ?? "").font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
                Text(progressText(d)).font(.system(size: 12)).monospacedDigit().foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            PillButton(icon: "folder", label: "Downloads") {
                NSWorkspace.shared.open(FileSource.downloadsFolder)
                m.collapse()
            }
            .frame(width: 128)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    func progressText(_ d: Download?) -> String {
        guard let d else { return "" }
        if d.fraction >= 0 { return "\(Int(d.fraction * 100))% · " + fmtBytes(d.bytes) }
        return fmtBytes(d.bytes) + " so far"
    }
}

struct ChargingCard: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Ring(progress: Double(m.battery.percent) / 100, color: Palette.green, line: 5)
                Image(systemName: "bolt.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.green)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(m.battery.percent)%").font(.system(size: 26, weight: .semibold)).monospacedDigit()
                Text(detail).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    var detail: String {
        let b = m.battery
        if b.charged || b.percent >= 100 { return "Fully charged" }
        if b.minutesToFull > 0 { return "Full in " + (b.minutesToFull >= 60 ? "\(b.minutesToFull / 60) h \(b.minutesToFull % 60) min" : "\(b.minutesToFull) min") }
        return b.charging ? "Charging" : "Plugged in, not charging"
    }
}
