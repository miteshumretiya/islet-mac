import AppKit
import SwiftUI
import Carbon

// MARK: - The window that holds the island

final class NotchPanel: NSPanel {
    var wantsKey = false
    override var canBecomeKey: Bool { wantsKey }
    override var canBecomeMain: Bool { false }
}

/// Buttons react to the first click even though Islet never becomes the active app.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class PanelController {
    let model: IslandModel
    var panel: NotchPanel!
    private var poll: Timer?
    private var monitors: [Any] = []
    private var pressTimer: Timer?

    init(model: IslandModel) {
        self.model = model
    }

    func build() {
        let p = NotchPanel(contentRect: NSRect(origin: .zero, size: IslandModel.panelSize),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.isMovable = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        MainActor.assumeIsolated {
            let host = IslandHostingView(rootView: IslandRoot(m: model))
            host.frame = NSRect(origin: .zero, size: IslandModel.panelSize)
            p.contentView = host
        }
        panel = p
        place()
        p.orderFrontRegardless()

        model.onWantKey = { [weak self] on in self?.setKey(on) }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.place()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.panel.orderFrontRegardless()
        }
        poll = Timer.scheduledTimer(withTimeInterval: 1.0 / 40.0, repeats: true) { [weak self] _ in self?.pollMouse() }
        RunLoop.main.add(poll!, forMode: .common)

        // clicks elsewhere fold the island away
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.model.clickedOutside()
        }) { monitors.append(g) }
        // scrolling over the island: volume, swipe up to dismiss, swipe sideways to switch
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel], handler: { [weak self] ev in
            self?.scrolled(ev)
            return ev
        }) { monitors.append(l) }
        if let l2 = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp], handler: { [weak self] ev in
            guard let self else { return ev }
            if ev.type == .leftMouseDown { if ev.window === self.panel { self.model.pressing = true } }
            else if self.model.pressing { self.model.pressing = false }
            return ev
        }) { monitors.append(l2) }
    }

    /// The screen with the notch (the MacBook's own display), or the main screen with a drawn notch.
    func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    func place() {
        guard let s = targetScreen() else { return }
        let f = s.frame
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            model.notch = CGSize(width: f.width - l.width - r.width, height: s.safeAreaInsets.top)
            model.hasNotch = true
        } else {
            let menuBar = max(24, f.maxY - s.visibleFrame.maxY)
            model.notch = CGSize(width: 190, height: min(36, menuBar))
            model.hasNotch = false
        }
        let size = IslandModel.panelSize
        panel.setFrame(NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height), display: true)
        model.refresh()
    }

    private func local(_ p: NSPoint) -> CGPoint {
        CGPoint(x: p.x - panel.frame.minX, y: panel.frame.maxY - p.y)
    }

    private func pollMouse() {
        let p = local(NSEvent.mouseLocation)
        let hit = model.hitRect.insetBy(dx: -2, dy: -2)
        let inside = hit.contains(p) || (model.hitRect.minY <= 0 && p.y < 0 && hit.minX <= p.x && p.x <= hit.maxX)
        let notchZone = CGRect(x: (IslandModel.panelSize.width - model.notch.width) / 2 - 10, y: -4,
                               width: model.notch.width + 20, height: model.notch.height + 6)
        let zone = notchZone.contains(p) || (model.peek && inside)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        model.setHover(inside, inZone: zone)
        if case .expanded = model.mode {
            if inside { lastInside = Date() } else if Date().timeIntervalSince(lastInside) > 3 { model.collapse() }
        } else {
            lastInside = Date()
        }
    }
    private var lastInside = Date()

    private func scrolled(_ ev: NSEvent) {
        guard model.hovering else { return }
        var dy = ev.scrollingDeltaY, dx = ev.scrollingDeltaX
        if !ev.hasPreciseScrollingDeltas { dy *= 8; dx *= 8 }
        if ev.isDirectionInvertedFromDevice { dy = -dy; dx = -dx }      // dy > 0 now means "fingers moved up"
        model.scroll(dx: dx, dy: dy)
    }

    func setKey(_ on: Bool) {
        panel.wantsKey = on
        if on {
            panel.makeKeyAndOrderFront(nil)
        } else if panel.isKeyWindow {
            // hand the keyboard back to the app you were using
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }
}

// MARK: - Global shortcut (⌥Space, or ⌃⌥Space if that's taken)

final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
                guard let ctx else { return 0 }
                let me = Unmanaged<HotKey>.fromOpaque(ctx).takeUnretainedValue()
                DispatchQueue.main.async { me.action() }
                return 0
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x49534C54), id: 1)
        return RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = IslandModel()
    var controller: PanelController!
    let media = MediaSource()
    let notifs = NotificationSource()
    let battery = BatterySource()
    let audio = AudioSource()
    let files = FileSource()
    let calendar = CalendarSource()
    var hotKey: HotKey?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var slowTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        Prefs.register()
        NSApp.setActivationPolicy(.accessory)
        model.media = media
        model.audio = audio
        model.onOpenSettings = { [weak self] in self?.openSettings() }

        controller = PanelController(model: model)
        controller.build()

        media.onUpdate = { [weak self] n, img in self?.model.mediaUpdated(n, img) }
        media.start()
        notifs.onNotif = { [weak self] n in self?.model.notification(n) }
        notifs.onAccess = { [weak self] ok in self?.model.notifAccess = ok }
        notifs.start()
        battery.onChange = { [weak self] b in self?.model.batteryChanged(b) }
        battery.start()
        audio.onVolume = { [weak self] v, m in self?.model.volumeChanged(v, m) }
        audio.onDevice = { [weak self] n, bt in self?.model.deviceChanged(n, bt) }
        audio.onMic = { [weak self] on in self?.model.micChanged(on) }
        audio.start()
        model.volume = audio.volume
        model.muted = audio.muted
        model.outputName = audio.outputName
        model.outputBT = audio.outputIsBluetooth
        files.onEvent = { [weak self] f in self?.model.fileEvent(f) }
        files.start()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let list = AppCatalog.load()
            DispatchQueue.main.async { self?.model.apps = list }
        }

        model.startTicking()
        slowTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.slowTick() }
        slowTick()

        let hk = HotKey { [weak self] in self?.model.toggleLauncher() }
        if !hk.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            hk.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | controlKey))
        }
        hotKey = hk

        buildStatusItem()

        let args = CommandLine.arguments
        if !Prefs.b(.firstRunDone) {
            Prefs.set(.firstRunDone, true)
            Prefs.launchAtLogin = true
            model.push(IslandEvent(.welcome, seconds: 9))
            openSettings()
        }
        if args.contains("--settings") { openSettings() }
        if args.contains("--launcher") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.model.openLauncher() } }
        if args.contains("--demo") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Demo.fill(self.model) } }
    }

    func applicationWillTerminate(_ note: Notification) {
        media.stop()
    }

    private func slowTick() {
        let cam = Prefs.b(.privacyDots) || Prefs.b(.calls) ? CameraSource.inUse() : false
        if cam != model.cameraInUse { model.cameraInUse = cam }
        if Prefs.b(.calendar) && calendar.granted { model.meetingsUpdated(calendar.upcoming()) }
        else if !model.meetings.isEmpty { model.meetings = [] }
        if model.mode != .hidden { controller.panel.orderFrontRegardless() }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Islet")
            b.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open launcher", action: #selector(menuLauncher), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Start focus", action: #selector(menuFocus), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Pause for 1 hour", action: #selector(menuPause), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Islet", action: #selector(menuQuit), keyEquivalent: "q").target = self
        menu.delegate = menuDelegate
        item.menu = menu
        statusItem = item
    }

    private lazy var menuDelegate = MenuUpdater(app: self)

    @objc func menuLauncher() { model.openLauncher() }
    @objc func menuFocus() { if model.focus.on { model.stopFocus() } else { model.startFocus() } }
    @objc func menuSettings() { openSettings() }
    @objc func menuPause() {
        model.pausedUntil = model.paused ? nil : Date().addingTimeInterval(3600)
        model.collapse()
        model.refresh()
    }
    @objc func menuQuit() { NSApp.terminate(nil) }

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "Islet Settings"
            w.isReleasedWhenClosed = false
            MainActor.assumeIsolated {
                w.contentViewController = NSHostingController(rootView: SettingsView(m: model, calendar: calendar))
            }
            w.setContentSize(NSSize(width: 520, height: 720))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

final class MenuUpdater: NSObject, NSMenuDelegate {
    weak var app: AppDelegate?
    init(app: AppDelegate) { self.app = app }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let app else { return }
        menu.item(at: 1)?.title = app.model.focus.on ? "Stop focus" : "Start focus"
        menu.item(at: 4)?.title = app.model.paused ? "Resume" : "Pause for 1 hour"
    }
}
