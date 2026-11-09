import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--gallery") {
    let out = i + 1 < args.count ? args[i + 1] : "islet-gallery.png"
    _ = NSApplication.shared
    exit(Gallery.render(to: out) ? 0 : 1)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
