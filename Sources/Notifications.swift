import AppKit
import SQLite3

struct NotifItem {
    let id: Int64
    let bundle: String
    let title: String
    let subtitle: String
    let body: String
}

/// New notifications, read from macOS's own Notification Center database (read-only).
/// That file is protected, so Islet needs Full Disk Access for this.
final class NotificationSource {
    var onNotif: ((NotifItem) -> Void)?
    var onAccess: ((Bool) -> Void)?
    private(set) var available = false

    private var db: OpaquePointer?
    private var lastId: Int64 = -1
    private var timer: Timer?
    private let q = DispatchQueue(label: "islet.notifications")

    static var dbPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let modern = home + "/Library/Group Containers/group.com.apple.usernoted/db2/db"   // macOS 15 and later
        var buf = [CChar](repeating: 0, count: 1024)
        if confstr(_CS_DARWIN_USER_DIR, &buf, buf.count) > 0 {
            let legacy = String(cString: buf) + "com.apple.notificationcenter/db2/db"     // macOS 14
            if FileManager.default.isReadableFile(atPath: legacy) { return legacy }
        }
        return modern
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    private func setAvailable(_ v: Bool) {
        guard v != available else { return }
        available = v
        DispatchQueue.main.async { self.onAccess?(v) }
    }

    private func open() -> Bool {
        if db != nil { return true }
        var h: OpaquePointer?
        if sqlite3_open_v2(Self.dbPath, &h, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            if h != nil { sqlite3_close(h) }
            return false
        }
        sqlite3_busy_timeout(h, 250)
        // opening succeeds lazily; a real read tells us whether access is allowed
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(h, "SELECT MAX(rec_id) FROM record", -1, &st, nil) == SQLITE_OK else {
            sqlite3_close(h)
            return false
        }
        var ok = false
        if sqlite3_step(st) == SQLITE_ROW {
            ok = true
            if lastId < 0 { lastId = sqlite3_column_int64(st, 0) }
        }
        sqlite3_finalize(st)
        if !ok { sqlite3_close(h); return false }
        db = h
        return true
    }

    private func poll() {
        q.async { [weak self] in
            guard let self else { return }
            guard self.open() else { self.setAvailable(false); return }
            self.setAvailable(true)
            let sql = "SELECT r.rec_id, IFNULL(a.identifier, ''), r.data FROM record r LEFT JOIN app a ON a.app_id = r.app_id WHERE r.rec_id > ? ORDER BY r.rec_id LIMIT 30"
            var st: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &st, nil) == SQLITE_OK else {
                sqlite3_close(self.db)
                self.db = nil
                return
            }
            sqlite3_bind_int64(st, 1, self.lastId)
            var items: [NotifItem] = []
            while sqlite3_step(st) == SQLITE_ROW {
                let id = sqlite3_column_int64(st, 0)
                self.lastId = max(self.lastId, id)
                var bundle = ""
                if let c = sqlite3_column_text(st, 1) { bundle = String(cString: c) }
                guard let blob = sqlite3_column_blob(st, 2) else { continue }
                let data = Data(bytes: blob, count: Int(sqlite3_column_bytes(st, 2)))
                guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { continue }
                if let app = plist["app"] as? String, !app.isEmpty { bundle = app }
                let req = plist["req"] as? [String: Any] ?? [:]
                let title = req["titl"] as? String ?? ""
                let sub = req["subt"] as? String ?? ""
                let body = req["body"] as? String ?? ""
                if title.isEmpty && body.isEmpty { continue }
                if bundle == Bundle.main.bundleIdentifier || bundle == "com.apple.screencaptureui" { continue }
                items.append(NotifItem(id: id, bundle: bundle, title: title, subtitle: sub, body: body))
            }
            sqlite3_finalize(st)
            if !items.isEmpty {
                DispatchQueue.main.async { for i in items { self.onNotif?(i) } }
            }
        }
    }
}
