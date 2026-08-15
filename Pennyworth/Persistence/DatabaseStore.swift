import Foundation
import SQLite3

private func sqliteTransient() -> sqlite3_destructor_type {
    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

actor DatabaseStore {
    private let url: URL
    private var handle: OpaquePointer?
    private(set) var usingMemoryFallback = false
    private(set) var openErrorReason: String?

    init(url: URL) {
        self.url = url
    }

    private var directory: URL {
        url.deletingLastPathComponent()
    }

    func open() {
        guard handle == nil else { return }
        cleanupExpiredRecoverySets()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            openErrorReason = "The database directory could not be created."
            usingMemoryFallback = true
            return
        }

        guard let candidate = openConnection(url: url) else {
            openErrorReason = "The database could not be opened. Learned ranking and web search settings are unavailable this session."
            usingMemoryFallback = true
            return
        }

        if databaseIsHealthy(candidate) {
            try? DatabaseMigration.migrate(candidate)
            handle = candidate
            return
        }

        sqlite3_close_v2(candidate)
        if quarantineDamagedDatabase() {
            if let fresh = openConnection(url: url) {
                try? DatabaseMigration.migrate(fresh)
                handle = fresh
                openErrorReason = "The database was damaged and moved to a recovery set. A fresh database was created."
                return
            }
        }
        openErrorReason = "The database could not be opened. Learned ranking and web search settings are unavailable this session."
        usingMemoryFallback = true
    }

    private func openConnection(url: URL) -> OpaquePointer? {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else {
            if database != nil {
                sqlite3_close_v2(database)
            }
            return nil
        }
        sqlite3_exec(database, "PRAGMA journal_mode=WAL", nil, nil, nil)
        return database
    }

    private func databaseIsHealthy(_ database: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v2(database, "SELECT 1 FROM sqlite_master LIMIT 1", -1, &statement, nil)
        if code == SQLITE_OK {
            sqlite3_finalize(statement)
            return true
        }
        return false
    }

    private func quarantineDamagedDatabase() -> Bool {
        let manager = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let recoveryDirectory = directory.appendingPathComponent("recovery-\(formatter.string(from: Date()))")
        do {
            try manager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let candidate = URL(fileURLWithPath: url.path + suffix)
                if manager.fileExists(atPath: candidate.path) {
                    let destination = recoveryDirectory.appendingPathComponent(candidate.lastPathComponent)
                    try manager.moveItem(at: candidate, to: destination)
                }
            }
            return true
        } catch {
            return false
        }
    }

    private func cleanupExpiredRecoverySets() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let now = Date()
        for name in names where name.hasPrefix("recovery-") {
            let item = directory.appendingPathComponent(name)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: item.path),
                let created = attributes[.creationDate] as? Date
            else { continue }
            if now.timeIntervalSince(created) > 7 * 24 * 3600 {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    func close() {
        if let handle {
            sqlite3_close_v2(handle)
        }
        handle = nil
    }

    private func withHandle(_ body: (OpaquePointer) -> Void) {
        guard let handle else { return }
        body(handle)
    }

    private func bindText(_ statement: OpaquePointer!, _ index: Int32, _ value: String) {
        value.withCString { cString in
            _ = sqlite3_bind_text(statement, index, cString, -1, sqliteTransient())
        }
    }

    private func textColumn(_ statement: OpaquePointer!, _ index: Int32) -> String {
        guard let cursor = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cursor)
    }

    // MARK: - Web searches

    func loadWebSearches() -> [WebSearch] {
        var searches: [WebSearch] = []
        withHandle { database in
            var statement: OpaquePointer?
            let sql = "SELECT id, name, keyword, url_template, is_enabled, sort_order, created_at, updated_at FROM web_searches ORDER BY sort_order"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                searches.append(readWebSearch(statement))
            }
        }
        return searches
    }

    private func readWebSearch(_ statement: OpaquePointer!) -> WebSearch {
        var search = WebSearch(
            id: textColumn(statement, 0),
            name: textColumn(statement, 1),
            keyword: textColumn(statement, 2),
            urlTemplate: textColumn(statement, 3),
            isEnabled: sqlite3_column_int(statement, 4) != 0,
            sortOrder: Int(sqlite3_column_int(statement, 5)),
            createdAt: nil,
            updatedAt: nil
        )
        let created = sqlite3_column_double(statement, 6)
        let updated = sqlite3_column_double(statement, 7)
        if created > 0 { search.createdAt = Date(timeIntervalSince1970: created) }
        if updated > 0 { search.updatedAt = Date(timeIntervalSince1970: updated) }
        return search
    }

    func saveWebSearch(_ search: WebSearch) {
        withHandle { database in
            var statement: OpaquePointer?
            let sql = """
                INSERT OR REPLACE INTO web_searches
                (id, name, keyword, url_template, is_enabled, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, search.id)
            bindText(statement, 2, search.name)
            bindText(statement, 3, search.keyword)
            bindText(statement, 4, search.urlTemplate)
            sqlite3_bind_int(statement, 5, search.isEnabled ? 1 : 0)
            sqlite3_bind_int(statement, 6, Int32(search.sortOrder))
            sqlite3_bind_double(statement, 7, search.createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
            sqlite3_bind_double(statement, 8, search.updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
            sqlite3_step(statement)
        }
    }

    func replaceAllWebSearches(_ searches: [WebSearch]) {
        withHandle { database in
            sqlite3_exec(database, "DELETE FROM web_searches", nil, nil, nil)
        }
        for search in searches {
            saveWebSearch(search)
        }
    }

    func deleteWebSearch(id: String) {
        withHandle { database in
            var statement: OpaquePointer?
            let sql = "DELETE FROM web_searches WHERE id = ?"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, id)
            sqlite3_step(statement)
        }
    }

    // MARK: - Selection events

    func loadSelectionEvents() -> [SelectionEvent] {
        var events: [SelectionEvent] = []
        withHandle { database in
            var statement: OpaquePointer?
            let sql = "SELECT provider_id, candidate_id, query_mode, normalized_query, action_id, selected_at FROM selection_events"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                events.append(SelectionEvent(
                    providerID: textColumn(statement, 0),
                    candidateID: textColumn(statement, 1),
                    queryMode: textColumn(statement, 2),
                    normalizedQuery: textColumn(statement, 3),
                    actionID: textColumn(statement, 4),
                    selectedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                ))
            }
        }
        return events
    }

    func insertSelectionEvent(_ event: SelectionEvent) {
        withHandle { database in
            var statement: OpaquePointer?
            let sql = """
                INSERT INTO selection_events
                (provider_id, candidate_id, query_mode, normalized_query, action_id, selected_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, event.providerID)
            bindText(statement, 2, event.candidateID)
            bindText(statement, 3, event.queryMode)
            bindText(statement, 4, event.normalizedQuery)
            bindText(statement, 5, event.actionID)
            sqlite3_bind_double(statement, 6, event.selectedAt.timeIntervalSince1970)
            sqlite3_step(statement)
        }
    }

    func resetLearnedRanking() {
        withHandle { database in
            sqlite3_exec(database, "DELETE FROM selection_events", nil, nil, nil)
            sqlite3_exec(database, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil)
        }
    }

    func pruneSelections(now: Date) {
        let cutoff = now.addingTimeInterval(-28 * 24 * 3600).timeIntervalSince1970
        withHandle { database in
            var statement: OpaquePointer?
            let sql = "DELETE FROM selection_events WHERE selected_at < ?"
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_double(statement, 1, cutoff)
            sqlite3_step(statement)
        }
    }
}