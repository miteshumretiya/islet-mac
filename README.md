# Islet for Mac

A dynamic island that lives in your MacBook's notch: music, notifications, charging, volume, AirPods,
timers & focus, screenshots, downloads, calls, your next meeting, and a launcher. On a Mac without a
notch (or an external display) it draws its own.

## Build
    ./build.sh            # → dist/Islet.app and dist/Islet.zip (universal, macOS 14+)

GitHub Actions builds every push to `main` on a Mac and publishes `Islet.zip`, a gallery of all states
and launch screenshots to the `build-output` branch.

## Run options
    Islet --settings      open Settings
    Islet --launcher      open the launcher
    Islet --demo N        show sample state N
    Islet --gallery x.png draw every state into a picture

## Sources
- `Sources/Model.swift` – what the island shows and when · `Views.swift`, `Cards.swift` – the island
- `Media.swift` + `Adapter/` – Now Playing (MediaRemote via Apple's perl; Spotify/Music AppleScript fallback)
- `Notifications.swift` – Notification Center database (needs Full Disk Access)
- `System.swift` – battery, sound/AirPods, mic & camera, screenshots/downloads, apps, calendar
- `App.swift` – the notch window, mouse handling, ⌥Space, menu bar item · `SettingsView.swift`
