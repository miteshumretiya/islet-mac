import AppKit
import SwiftUI

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }

func fmtDur(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded(.down)))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}

func fmtBytes(_ b: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f.string(fromByteCount: b)
}

func minLabel(_ sec: Int) -> String {
    if sec < 60 { return "\(sec) sec" }
    if sec % 60 == 0 { return "\(sec / 60) min" }
    return String(format: "%d:%02d min", sec / 60, sec % 60)
}

func ago(_ d: Date) -> String {
    let s = Int(Date().timeIntervalSince(d))
    if s < 60 { return "now" }
    if s < 3600 { return "\(s / 60)m" }
    if s < 86400 { return "\(s / 3600)h" }
    return "\(s / 86400)d"
}

/// The dominant lively colour of an image (album art, app icon), or nil.
func accentColor(_ img: NSImage?) -> NSColor? {
    guard let img, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let w = 12, h = 12
    var px = [UInt8](repeating: 0, count: w * h * 4)
    var ok = false
    px.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        ok = true
    }
    guard ok else { return nil }
    var sr = 0.0, sg = 0.0, sb = 0.0, sw = 0.0
    for i in 0..<(w * h) {
        let a = Double(px[i * 4 + 3]) / 255
        if a < 0.5 { continue }
        let r = Double(px[i * 4]) / 255 / a, g = Double(px[i * 4 + 1]) / 255 / a, b = Double(px[i * 4 + 2]) / 255 / a
        let mx = max(r, g, b), mn = min(r, g, b)
        let sat = mx > 0 ? (mx - mn) / mx : 0
        let wgt = 0.05 + sat * sat * mx
        sr += r * wgt; sg += g * wgt; sb += b * wgt; sw += wgt
    }
    guard sw > 0 else { return nil }
    var r = sr / sw, g = sg / sw, b = sb / sw
    let mx = max(r, g, b, 0.001)
    if mx < 0.75 { r *= 0.75 / mx; g *= 0.75 / mx; b *= 0.75 / mx }   // keep it bright enough on black
    return NSColor(calibratedRed: CGFloat(min(r, 1)), green: CGFloat(min(g, 1)), blue: CGFloat(min(b, 1)), alpha: 1)
}

func shifted(_ c: NSColor, _ dh: CGFloat) -> NSColor {
    let k = c.usingColorSpace(.deviceRGB) ?? c
    var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
    k.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
    var nh = h + dh / 360
    if nh < 0 { nh += 1 }
    if nh > 1 { nh -= 1 }
    return NSColor(deviceHue: nh, saturation: max(0.45, s), brightness: max(0.8, v), alpha: 1)
}

/// Finds a one-time code ("482913 is your OTP…", "G-123456", "Your code: 123 456").
func findOTP(_ title: String, _ body: String) -> String? {
    let text = title + "\n" + body
    let lower = text.lowercased()
    let keys = ["code", "otp", "password", "passcode", "verification", "verify", "pin", "2fa", "one-time", "one time",
                "login", "log in", "sign in", "sign-in", "security", "authentication", "token", "confirm", "kod", "codice", "código"]
    guard keys.contains(where: { lower.contains($0) }) else { return nil }
    if let r = text.range(of: #"\bG-\d{6}\b"#, options: .regularExpression) {
        return String(text[r]).replacingOccurrences(of: "G-", with: "")
    }
    guard let re = try? NSRegularExpression(pattern: #"(?<![\d.,:/])(\d{3}[ -]\d{3}|\d{4,8})(?![\d]|[.,:/]\d)"#) else { return nil }
    let ns = text as NSString
    let money = ["rs", "₹", "$", "€", "£", "inr", "usd", "eur", "gbp", "amount", "bill", "payment of", "paid", "balance", "total", "price"]
    for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        let token = ns.substring(with: m.range)
        let digits = token.filter { $0.isNumber }
        if digits.count == 4, let y = Int(digits), y >= 1900, y <= 2099 { continue }   // a year
        let start = max(0, m.range.location - 14)
        let before = ns.substring(with: NSRange(location: start, length: m.range.location - start)).lowercased()
        if money.contains(where: { before.contains($0) }) { continue }
        return digits
    }
    return nil
}

/// Name, icon and location of an app from its bundle id (cached).
enum AppInfo {
    private static var cache: [String: (name: String, icon: NSImage?, url: URL?)] = [:]

    static func lookup(_ bundle: String) -> (name: String, icon: NSImage?, url: URL?) {
        if let c = cache[bundle] { return c }
        var name = bundle.components(separatedBy: ".").last ?? bundle
        var icon: NSImage?
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
        if let url {
            name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }
        let r = (name: name, icon: icon, url: url)
        cache[bundle] = r
        return r
    }

    static func open(_ bundle: String) {
        guard let url = lookup(bundle).url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

func playSound(_ name: String) {
    guard Prefs.b(.sounds) else { return }
    NSSound(named: NSSound.Name(name))?.play()
}

func haptic() {
    guard Prefs.b(.haptics) else { return }
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

enum Palette {
    static let green = Color(hex: 0x34C759)
    static let orange = Color(hex: 0xFF9F0A)
    static let blue = Color(hex: 0x0A84FF)
    static let red = Color(hex: 0xFF453A)
    static let pink = Color(hex: 0xFF375F)
    static let purple = Color(hex: 0x7A5CFF)
    static let aurora: [Color] = [Color(hex: 0x3DF5C8), Color(hex: 0x7A5CFF), Color(hex: 0xFF5CC8), Color(hex: 0x3DB8F5)]

    static func timeOfDay() -> [Color] {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10: return [Color(hex: 0xFFB86B), Color(hex: 0xFF7A90), Color(hex: 0xFFD27A)]
        case 10..<17: return [Color(hex: 0x5AC8FA), Color(hex: 0x7AE0C8), Color(hex: 0x9EB7FF)]
        case 17..<21: return [Color(hex: 0xFF8A5B), Color(hex: 0xD45BFF), Color(hex: 0xFF5B8A)]
        default: return [Color(hex: 0x5B6CFF), Color(hex: 0x8E5BFF), Color(hex: 0x3FA9F5)]
        }
    }
}
