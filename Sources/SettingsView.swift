import SwiftUI
import AppKit
import EventKit

struct SettingsView: View {
    @ObservedObject var m: IslandModel
    let calendar: CalendarSource

    @AppStorage("music") var music = true
    @AppStorage("nowPlaying") var nowPlaying = true
    @AppStorage("scrollVolume") var scrollVolume = true
    @AppStorage("notifs") var notifs = true
    @AppStorage("otp") var otp = true
    @AppStorage("notifSeconds") var notifSeconds = 6
    @AppStorage("missedDot") var missedDot = true
    @AppStorage("volumeHUD") var volumeHUD = true
    @AppStorage("outputDevice") var outputDevice = true
    @AppStorage("screenshots") var screenshots = true
    @AppStorage("downloads") var downloads = true
    @AppStorage("privacyDots") var privacyDots = true
    @AppStorage("calls") var calls = true
    @AppStorage("battery") var battery = true
    @AppStorage("chargingStay") var chargingStay = false
    @AppStorage("lowBattery") var lowBattery = true
    @AppStorage("calendar") var calendarOn = true
    @AppStorage("meetingAlerts") var meetingAlerts = true
    @AppStorage("focusMin") var focusMin = 25
    @AppStorage("breakMin") var breakMin = 5
    @AppStorage("sounds") var sounds = true
    @AppStorage("glow") var glow = 2
    @AppStorage("glowColors") var glowColors = 0
    @AppStorage("hoverPeek") var hoverPeek = true
    @AppStorage("haptics") var haptics = true
    @State var loginItem = Prefs.launchAtLogin
    @State var calStatus = EKEventStore.authorizationStatus(for: .event)

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Islet").font(.system(size: 22, weight: .semibold))
                        Text("A dynamic island for your MacBook's notch · version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Permissions") {
                PermissionRow(title: "Notifications", detail: "Needs Full Disk Access to read Notification Center",
                              ok: m.notifAccess, button: "Open Full Disk Access") {
                    open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
                }
                PermissionRow(title: "Calendar", detail: "For your next meeting and a Join button",
                              ok: calStatus == .fullAccess, button: calStatus == .notDetermined ? "Allow" : "Open Calendar access") {
                    if calStatus == .notDetermined {
                        calendar.request { _ in calStatus = EKEventStore.authorizationStatus(for: .event) }
                    } else {
                        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                    }
                }
            }

            Section("General") {
                Toggle("Open at login", isOn: Binding(get: { loginItem }, set: { Prefs.launchAtLogin = $0; loginItem = Prefs.launchAtLogin }))
                Toggle("Peek when the pointer touches the notch", isOn: $hoverPeek)
                Toggle("Trackpad haptics", isOn: $haptics)
                LabeledContent("Launcher shortcut") { Text("⌥ Space").foregroundStyle(.secondary) }
            }

            Section("Music") {
                Toggle("Show what's playing", isOn: $music)
                Toggle("Banner when the track changes", isOn: $nowPlaying)
                Toggle("Scroll on the island to change volume", isOn: $scrollVolume)
            }

            Section {
                Toggle("Show notifications", isOn: $notifs)
                Stepper(value: $notifSeconds, in: 2...30) { LabeledContent("Time on screen", value: "\(notifSeconds) s") }
                Toggle("Copy button for one-time codes", isOn: $otp)
                Toggle("Red dot for missed notifications", isOn: $missedDot)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Seeing them twice? In System Settings › Notifications, set an app's alert style to None. Islet still shows it, and it stays in Notification Center.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Section("Battery") {
                Toggle("Charging animation", isOn: $battery)
                Toggle("Keep showing while charging", isOn: $chargingStay)
                Toggle("Low battery alerts (20%, 10%, 5%)", isOn: $lowBattery)
            }

            Section("System") {
                Toggle("Volume changes", isOn: $volumeHUD)
                Toggle("Sound output changes (AirPods connected…)", isOn: $outputDevice)
                Toggle("Screenshots — copy, mark up or drag them anywhere", isOn: $screenshots)
                Toggle("Downloads — progress, then Open", isOn: $downloads)
                Toggle("Calls — timer and mute button while the mic is in use", isOn: $calls)
            }

            Section("Calendar") {
                Toggle("Show your next meeting in the launcher", isOn: $calendarOn)
                Toggle("Alert 5 minutes before, with a Join button", isOn: $meetingAlerts)
            }

            Section("Focus and timers") {
                Stepper(value: $focusMin, in: 5...120, step: 5) { LabeledContent("Focus length", value: "\(focusMin) min") }
                Stepper(value: $breakMin, in: 1...60) { LabeledContent("Break length", value: "\(breakMin) min") }
                Toggle("Sounds", isOn: $sounds)
            }

            Section("Ambient light") {
                Picker("Glow", selection: $glow) {
                    Text("Off").tag(0)
                    Text("Events").tag(1)
                    Text("Events + music").tag(2)
                    Text("Always").tag(3)
                }
                Picker("Colours", selection: $glowColors) {
                    Text("Match content").tag(0)
                    Text("Aurora").tag(1)
                    Text("Time of day").tag(2)
                }
            }

            Section {
                HStack {
                    Button("Open launcher") { m.openLauncher() }
                    Spacer()
                    Button("Quit Islet", role: .destructive) { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            calStatus = EKEventStore.authorizationStatus(for: .event)
            loginItem = Prefs.launchAtLogin
        }
        .onChange(of: music) { m.refresh() }
        .onChange(of: glow) { m.refresh() }
        .onChange(of: chargingStay) { m.refresh() }
    }

    func open(_ s: String) {
        if let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let ok: Bool
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !ok { Button(button, action: action) }
        }
    }
}
