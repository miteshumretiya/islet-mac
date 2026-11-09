import AppKit
import ServiceManagement

/// Every setting, stored in UserDefaults (com.islet.mac).
enum Pref: String {
    case music, nowPlaying, scrollVolume
    case notifs, otp, notifSeconds, missedDot
    case volumeHUD, outputDevice, screenshots, downloads, privacyDots, calls
    case battery, chargingStay, lowBattery
    case calendar, meetingAlerts
    case focusMin, breakMin, sounds
    case glow, glowColors
    case hoverPeek, haptics
    case pinned, firstRunDone
}

enum Prefs {
    static let d = UserDefaults.standard

    static func register() {
        d.register(defaults: [
            "music": true, "nowPlaying": true, "scrollVolume": true,
            "notifs": true, "otp": true, "notifSeconds": 6, "missedDot": true,
            "volumeHUD": true, "outputDevice": true, "screenshots": true, "downloads": true, "privacyDots": true, "calls": true,
            "battery": true, "chargingStay": false, "lowBattery": true,
            "calendar": true, "meetingAlerts": true,
            "focusMin": 25, "breakMin": 5, "sounds": true,
            "glow": 2, "glowColors": 0,
            "hoverPeek": true, "haptics": true,
            "pinned": "", "firstRunDone": false,
        ])
    }

    static func b(_ p: Pref) -> Bool { d.bool(forKey: p.rawValue) }
    static func i(_ p: Pref) -> Int { d.integer(forKey: p.rawValue) }
    static func s(_ p: Pref) -> String { d.string(forKey: p.rawValue) ?? "" }
    static func set(_ p: Pref, _ v: Any) { d.set(v, forKey: p.rawValue) }

    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Islet: login item: \(error)")
            }
        }
    }
}
