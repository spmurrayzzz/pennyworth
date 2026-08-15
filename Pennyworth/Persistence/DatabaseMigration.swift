import Foundation
import SQLite3

enum DatabaseMigration {
    static let schemaVersion: Int32 = 1

    static func userVersion(_ handle: OpaquePointer) -> Int32 {
        var statement: OpaquePointer?
        var version: Int32 = 0
        if sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = sqlite3_column_int(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return version
    }

    static func migrate(_ handle: OpaquePointer) throws {
        let current = userVersion(handle)
        guard current < schemaVersion else { return }

        guard sqlite3_exec(handle, "BEGIN", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.migrationFailed
        }
        defer {
            sqlite3_exec(handle, "COMMIT", nil, nil, nil)
        }

        if current < 1 {
            createVersion1(handle)
        }

        sqlite3_exec(handle, "PRAGMA user_version = 1", nil, nil, nil)
    }

    private static func createVersion1(_ handle: OpaquePointer) {
        sqlite3_exec(handle, """
            CREATE TABLE IF NOT EXISTS selection_events (
                id INTEGER PRIMARY KEY,
                provider_id TEXT NOT NULL,
                candidate_id TEXT NOT NULL,
                query_mode TEXT NOT NULL,
                normalized_query TEXT NOT NULL,
                action_id TEXT NOT NULL,
                selected_at REAL NOT NULL
            ) STRICT;
        """, nil, nil, nil)
        sqlite3_exec(handle, """
            CREATE INDEX IF NOT EXISTS selection_events_query_time
            ON selection_events(normalized_query, provider_id, candidate_id, selected_at);
        """, nil, nil, nil)
        sqlite3_exec(handle, """
            CREATE INDEX IF NOT EXISTS selection_events_candidate_time
            ON selection_events(provider_id, candidate_id, selected_at);
        """, nil, nil, nil)
        sqlite3_exec(handle, """
            CREATE TABLE IF NOT EXISTS web_searches (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                keyword TEXT NOT NULL UNIQUE,
                url_template TEXT NOT NULL,
                is_enabled INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                created_at REAL,
                updated_at REAL
            ) STRICT;
        """, nil, nil, nil)
    }
}

enum DatabaseError: Error {
    case migrationFailed
    case statementFailed
    case openFailed
    case closed
}