import AppKit
import CoreAudio
import AudioToolbox
import CoreMediaIO
import IOKit.ps
import EventKit

// MARK: - Battery

struct BatteryState: Equatable {
    var present = false
    var percent = 100
    var onAC = false
    var charging = false
    var charged = false
    var minutesToFull = -1
    var minutesToEmpty = -1
}

final class BatterySource {
    var onChange: ((BatteryState) -> Void)?
    private var source: CFRunLoopSource?

    func start() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatterySource>.fromOpaque(ctx).takeUnretainedValue().read()
        }, ctx)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
        read()
    }

    func read() {
        var s = BatteryState()
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            onChange?(s)
            return
        }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else { continue }
            if (d["Type"] as? String) != "InternalBattery" { continue }
            let cur = d["Current Capacity"] as? Int ?? 0
            let mx = max(1, d["Max Capacity"] as? Int ?? 100)
            s.present = true
            s.percent = clamp(Int((Double(cur) / Double(mx) * 100).rounded()), 0, 100)
            s.onAC = (d["Power Source State"] as? String) == "AC Power"
            s.charging = d["Is Charging"] as? Bool ?? false
            s.charged = d["Is Charged"] as? Bool ?? (s.onAC && s.percent >= 100)
            s.minutesToFull = d["Time to Full Charge"] as? Int ?? -1
            s.minutesToEmpty = d["Time to Empty"] as? Int ?? -1
        }
        onChange?(s)
    }
}

// MARK: - Sound output, volume, microphone

final class AudioSource {
    var onVolume: ((Float, Bool) -> Void)?          // level, muted
    var onDevice: ((String, Bool) -> Void)?         // name, is bluetooth
    var onMic: ((Bool) -> Void)?                    // something is recording

    private(set) var outputID = AudioObjectID(kAudioObjectUnknown)
    private(set) var inputID = AudioObjectID(kAudioObjectUnknown)
    private var started = false

    private static func addr(_ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultDevice(_ sel: AudioObjectPropertySelector) -> AudioObjectID {
        var a = addr(sel)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id)
        return id
    }

    func start() {
        guard !started else { return }
        started = true
        var outA = Self.addr(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outA, DispatchQueue.main) { [weak self] _, _ in
            self?.bindOutput(announce: true)
        }
        var inA = Self.addr(kAudioHardwarePropertyDefaultInputDevice)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &inA, DispatchQueue.main) { [weak self] _, _ in
            self?.bindInput()
        }
        bindOutput(announce: false)
        bindInput()
    }

    private var volBlock: AudioObjectPropertyListenerBlock?
    private var micBlock: AudioObjectPropertyListenerBlock?

    private func bindOutput(announce: Bool) {
        if outputID != kAudioObjectUnknown, let b = volBlock {
            var v = Self.addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(outputID, &v, DispatchQueue.main, b)
            var m = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(outputID, &m, DispatchQueue.main, b)
        }
        outputID = Self.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
        guard outputID != kAudioObjectUnknown else { return }
        let b: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.onVolume?(self.volume, self.muted)
        }
        volBlock = b
        var v = Self.addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(outputID, &v, DispatchQueue.main, b)
        var m = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(outputID, &m, DispatchQueue.main, b)
        if announce { onDevice?(deviceName(outputID), isBluetooth(outputID)) }
    }

    private func bindInput() {
        if inputID != kAudioObjectUnknown, let b = micBlock {
            var r = Self.addr(kAudioDevicePropertyDeviceIsRunningSomewhere)
            AudioObjectRemovePropertyListenerBlock(inputID, &r, DispatchQueue.main, b)
        }
        inputID = Self.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        guard inputID != kAudioObjectUnknown else { return }
        let b: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.onMic?(self.micRunning)
        }
        micBlock = b
        var r = Self.addr(kAudioDevicePropertyDeviceIsRunningSomewhere)
        AudioObjectAddPropertyListenerBlock(inputID, &r, DispatchQueue.main, b)
        onMic?(micRunning)
    }

    var volume: Float {
        var a = Self.addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(outputID, &a, 0, nil, &size, &v) == noErr else { return 0.5 }
        return v
    }

    var muted: Bool {
        var a = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(outputID, &a, 0, nil, &size, &v) == noErr else { return false }
        return v != 0
    }

    func setVolume(_ level: Float) {
        var a = Self.addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var v = Float32(clamp(level, 0, 1))
        AudioObjectSetPropertyData(outputID, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if v > 0 && muted { setMuted(false) }
    }

    func setMuted(_ on: Bool) {
        var a = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        var v = UInt32(on ? 1 : 0)
        AudioObjectSetPropertyData(outputID, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }

    var micRunning: Bool {
        var a = Self.addr(kAudioDevicePropertyDeviceIsRunningSomewhere)
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(inputID, &a, 0, nil, &size, &v) == noErr else { return false }
        return v != 0
    }

    var micMuted: Bool {
        var a = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput)
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(inputID, &a, 0, nil, &size, &v) == noErr else { return false }
        return v != 0
    }

    func setMicMuted(_ on: Bool) {
        var a = Self.addr(kAudioDevicePropertyMute, kAudioDevicePropertyScopeInput)
        var v = UInt32(on ? 1 : 0)
        AudioObjectSetPropertyData(inputID, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }

    var outputName: String { deviceName(outputID) }
    var outputIsBluetooth: Bool { isBluetooth(outputID) }

    private func deviceName(_ id: AudioObjectID) -> String {
        var a = Self.addr(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &name) == noErr, let n = name else { return "" }
        return n.takeRetainedValue() as String
    }

    private func isBluetooth(_ id: AudioObjectID) -> Bool {
        var a = Self.addr(kAudioDevicePropertyTransportType)
        var t = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &t) == noErr else { return false }
        return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
    }
}

// MARK: - Camera

enum CameraSource {
    /// true while any app uses a camera
    static func inUse() -> Bool {
        var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                          mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                          mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size = UInt32(0)
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &a, 0, nil, &size) == 0, size > 0 else { return false }
        let n = Int(size) / MemoryLayout<CMIODeviceID>.size
        var ids = [CMIODeviceID](repeating: 0, count: n)
        var used = UInt32(0)
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &a, 0, nil, size, &used, &ids) == 0 else { return false }
        for id in ids {
            var r = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                              mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                              mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var v = UInt32(0)
            var u = UInt32(0)
            if CMIOObjectGetPropertyData(id, &r, 0, nil, UInt32(MemoryLayout<UInt32>.size), &u, &v) == 0, v != 0 { return true }
        }
        return false
    }
}

// MARK: - Folders (screenshots, downloads)

final class FolderWatch {
    let url: URL
    var onChange: (() -> Void)?
    private var src: DispatchSourceFileSystemObject?

    init(_ url: URL) { self.url = url }

    func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .extend], queue: .main)
        s.setEventHandler { [weak self] in self?.onChange?() }
        s.setCancelHandler { close(fd) }
        s.resume()
        src = s
    }
}

struct FileEvent {
    enum Kind { case screenshot, downloaded, progress, progressEnded }
    var kind: Kind
    var url: URL
    var name: String
    var bytes: Int64 = 0
    var fraction: Double = -1
}

final class FileSource {
    var onEvent: ((FileEvent) -> Void)?
    private var shotWatch: FolderWatch?
    private var dlWatch: FolderWatch?
    private var shotNames = Set<String>()
    private var dlNames = Set<String>()
    private var partials: [String: Int64] = [:]
    private var pollTimer: Timer?
    private var burstStart = Date.distantPast
    private var burst = 0

    static var screenshotFolder: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let loc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !loc.isEmpty {
            let p = (loc as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue { return URL(fileURLWithPath: p) }
        }
        return home.appendingPathComponent("Desktop")
    }

    static var downloadsFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    func start() {
        let shots = Self.screenshotFolder, dls = Self.downloadsFolder
        shotNames = Set(list(shots))
        dlNames = Set(list(dls))
        let sw = FolderWatch(shots)
        sw.onChange = { [weak self] in self?.scanShots() }
        sw.start()
        shotWatch = sw
        if dls != shots {
            let dw = FolderWatch(dls)
            dw.onChange = { [weak self] in self?.scanDownloads() }
            dw.start()
            dlWatch = dw
        }
    }

    private func list(_ u: URL) -> [String] { (try? FileManager.default.contentsOfDirectory(atPath: u.path)) ?? [] }

    private static func isShot(_ n: String) -> Bool {
        let l = n.lowercased()
        guard !n.hasPrefix(".") else { return false }
        let ext = (l as NSString).pathExtension
        guard ["png", "jpg", "jpeg", "heic", "tiff", "pdf"].contains(ext) else { return false }
        return l.hasPrefix("screenshot") || l.hasPrefix("screen shot") || l.hasPrefix("cleanshot") || l.contains("screenshot")
    }

    private static func isPartial(_ n: String) -> Bool {
        let l = n.lowercased()
        return l.hasSuffix(".crdownload") || l.hasSuffix(".part") || l.hasSuffix(".download") || l.hasSuffix(".partial") || l.hasSuffix(".opdownload")
    }

    private func scanShots() {
        let folder = Self.screenshotFolder
        let now = Set(list(folder))
        let added = now.subtracting(shotNames)
        shotNames = now
        for n in added where Self.isShot(n) {
            let u = folder.appendingPathComponent(n)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.onEvent?(FileEvent(kind: .screenshot, url: u, name: n, bytes: Self.size(u)))
            }
        }
        if folder == Self.downloadsFolder { scanDownloads() }
    }

    private func scanDownloads() {
        let folder = Self.downloadsFolder
        let now = Set(list(folder))
        let added = now.subtracting(dlNames)
        let removed = dlNames.subtracting(now)
        dlNames = now
        for n in now where Self.isPartial(n) && partials[n] == nil { partials[n] = -1 }
        let finishedFromPartial = removed.contains(where: Self.isPartial)
        for n in removed where Self.isPartial(n) {
            partials[n] = nil
            onEvent?(FileEvent(kind: .progressEnded, url: folder.appendingPathComponent(n), name: n))
        }
        for n in added where !Self.isPartial(n) && !n.hasPrefix(".") {
            let u = folder.appendingPathComponent(n)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
            if isDir.boolValue && !finishedFromPartial { continue }
            if !finishedFromPartial {        // something saved straight into Downloads: announce at most two in a burst
                if Date().timeIntervalSince(burstStart) > 3 { burstStart = Date(); burst = 0 }
                burst += 1
                if burst > 2 { continue }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let sz = Self.size(u)
                guard sz > 0 || isDir.boolValue else { return }
                self?.onEvent?(FileEvent(kind: .downloaded, url: u, name: n, bytes: sz))
            }
        }
        updateTimer()
    }

    private func updateTimer() {
        if partials.isEmpty { pollTimer?.invalidate(); pollTimer = nil; return }
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in self?.pollPartials() }
        pollPartials()
    }

    private func pollPartials() {
        let folder = Self.downloadsFolder
        for (n, last) in partials {
            let u = folder.appendingPathComponent(n)
            var bytes = Self.size(u)
            var fraction = -1.0
            if n.lowercased().hasSuffix(".download") {            // Safari keeps progress in Info.plist
                let info = u.appendingPathComponent("Info.plist")
                if let d = NSDictionary(contentsOf: info) {
                    let done = (d["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value ?? 0
                    let total = (d["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value ?? 0
                    if done > 0 { bytes = done }
                    if total > 0 { fraction = Double(done) / Double(total) }
                }
            }
            if bytes != last {
                partials[n] = bytes
                var clean = n
                for suf in [".crdownload", ".part", ".download", ".partial", ".opdownload"] where clean.lowercased().hasSuffix(suf) {
                    clean = String(clean.dropLast(suf.count))
                }
                if clean.hasPrefix("Unconfirmed ") { clean = "Downloading" }
                onEvent?(FileEvent(kind: .progress, url: u, name: clean, bytes: max(0, bytes), fraction: fraction))
            }
        }
    }

    static func size(_ u: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir) else { return -1 }
        if !isDir.boolValue {
            return ((try? FileManager.default.attributesOfItem(atPath: u.path))?[.size] as? NSNumber)?.int64Value ?? 0
        }
        var total: Int64 = 0
        if let e = FileManager.default.enumerator(at: u, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let f as URL in e { total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) }
        }
        return total
    }
}

// MARK: - Apps for the launcher

struct AppEntry: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let lower: String
}

enum AppCatalog {
    static func load() -> [AppEntry] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                    "/System/Library/CoreServices/Applications", home + "/Applications"]
        var seen = Set<String>()
        var out: [AppEntry] = []
        for d in dirs {
            for n in (try? fm.contentsOfDirectory(atPath: d)) ?? [] where n.hasSuffix(".app") {
                let path = d + "/" + n
                var name = fm.displayName(atPath: path)
                if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
                if seen.contains(name.lowercased()) { continue }
                seen.insert(name.lowercased())
                out.append(AppEntry(name: name, path: path, lower: name.lowercased()))
            }
        }
        out.append(AppEntry(name: "Finder", path: "/System/Library/CoreServices/Finder.app", lower: "finder"))
        return out.sorted { $0.lower < $1.lower }
    }
}

// MARK: - Calendar

struct MeetingInfo: Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let link: URL?
    let color: NSColor?
}

final class CalendarSource {
    let store = EKEventStore()
    var status: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .event) }
    var granted: Bool { status == .fullAccess }

    func request(_ done: @escaping (Bool) -> Void) {
        store.requestFullAccessToEvents { ok, _ in DispatchQueue.main.async { done(ok) } }
    }

    func upcoming() -> [MeetingInfo] {
        guard granted else { return [] }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(14 * 3600), calendars: nil)
        return store.events(matching: pred)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { e in
                MeetingInfo(id: e.eventIdentifier ?? UUID().uuidString, title: e.title ?? "Event", start: e.startDate, end: e.endDate,
                            link: Self.link(e), color: e.calendar?.color)
            }
    }

    private static func link(_ e: EKEvent) -> URL? {
        if let u = e.url, isMeeting(u.absoluteString) { return u }
        let text = [e.location ?? "", e.notes ?? ""].joined(separator: "\n")
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for m in det.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
            if let u = m.url, isMeeting(u.absoluteString) { return u }
        }
        return nil
    }

    private static func isMeeting(_ s: String) -> Bool {
        let l = s.lowercased()
        return ["zoom.us/", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "whereby.com", "facetime.apple.com"]
            .contains { l.contains($0) }
    }
}
