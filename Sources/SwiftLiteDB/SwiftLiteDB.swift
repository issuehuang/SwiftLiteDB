import Foundation
import SQLite

// @unchecked Sendable is justified: all database access is serialized via `lock`.
public final class SwiftLiteDB: @unchecked Sendable {
    private var db: Connection?
    private let dbName: String
    private let dbPath: String
    // NSRecursiveLock allows re-entrant locking on the same thread (needed inside transactions).
    private let lock = NSRecursiveLock()

    public var enableLocationTracking: Bool = false
    public var enableLogging: Bool = false
    public var enableDebugMode: Bool = false {
        didSet {
            if enableDebugMode {
                enableLocationTracking = true
                enableLogging = true
            }
        }
    }

    public var databasePath: String? {
        guard enableLocationTracking else { return nil }
        return dbPath
    }

    public init(name: String) throws {
        self.dbName = name
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dbPath = documentsPath.appendingPathComponent("\(dbName).sqlite").path
        try setupDatabase()
    }

    private func setupDatabase() throws {
        db = try Connection(dbPath)
        if enableLogging {
            print("Database initialized at: \(dbPath)")
        }
    }

    public func createTable(name: String, columns: [String], foreignKeys: [ForeignKey]? = nil) throws {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }

        // Table/column names are schema identifiers from code, not user data — DDL cannot use ? bindings.
        var sql = "CREATE TABLE IF NOT EXISTS \(name) ("
        sql += columns.joined(separator: ", ")

        if let foreignKeys = foreignKeys, !foreignKeys.isEmpty {
            sql += ", "
            sql += foreignKeys.map { $0.sqlString() }.joined(separator: ", ")
        }

        sql += ")"

        if enableLogging { print("Executing SQL: \(sql)") }

        lock.lock()
        defer { lock.unlock() }
        try db.execute(sql)
    }

    public func insert(into table: String, values: [String: Any]) throws {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }

        let columns = values.keys.joined(separator: ", ")
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        let sql = "INSERT INTO \(table) (\(columns)) VALUES (\(placeholders))"

        if enableLogging {
            print("Executing SQL: \(sql)")
            print("With values: \(values)")
        }

        let bindingValues = values.values.compactMap { anyToBinding($0) }

        lock.lock()
        defer { lock.unlock() }
        try db.run(sql, bindingValues)
    }

    /// Query rows from a table. Use `?` placeholders in `condition` and pass values in `parameters`.
    public func query(from table: String, where condition: String? = nil, parameters: [Any] = []) throws -> [[String: Any]] {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }

        var sql = "SELECT * FROM \(table)"
        if let condition = condition {
            sql += " WHERE \(condition)"
        }

        if enableLogging { print("Executing SQL: \(sql)") }

        let bindingParams = parameters.compactMap { anyToBinding($0) }

        lock.lock()
        defer { lock.unlock() }

        var results: [[String: Any]] = []
        let statement = try db.prepare(sql, bindingParams)
        for row in statement {
            var dict: [String: Any] = [:]
            for (index, name) in statement.columnNames.enumerated() {
                dict[name] = row[index]
            }
            results.append(dict)
        }
        return results
    }

    public func transaction(_ block: (SwiftLiteDB) throws -> Void) throws {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }

        lock.lock()
        defer { lock.unlock() }
        try db.transaction {
            try block(self)
        }
    }

    public func execute(_ sql: String, parameters: [Any]? = nil) throws -> [[String: Any]] {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }

        if enableLogging {
            print("Executing SQL: \(sql)")
            if let parameters = parameters { print("With parameters: \(parameters)") }
        }

        let bindingParams = parameters?.compactMap { anyToBinding($0) } ?? []

        lock.lock()
        defer { lock.unlock() }

        let statement = try db.prepare(sql, bindingParams)
        var results: [[String: Any]] = []
        for row in statement {
            var dict: [String: Any] = [:]
            for (index, name) in statement.columnNames.enumerated() {
                dict[name] = row[index]
            }
            results.append(dict)
        }
        return results
    }

    // MARK: - Internal Helpers

    private func anyToBinding(_ value: Any) -> Binding? {
        if let s = value as? String   { return s }
        if let i = value as? Int      { return Int64(i) }
        if let i = value as? Int64    { return i }
        if let d = value as? Double   { return d }
        if let b = value as? Bool     { return b }
        if value is NSNull            { return nil }
        return nil
    }

    // MARK: - Debug Functions

    public func printDatabaseLocation() {
        print("===== SwiftLiteDB Debug Info =====")
        print("Database Name: \(dbName)")
        print("Database Path: \(dbPath)")
        print("Database exists: \(FileManager.default.fileExists(atPath: dbPath))")

        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: dbPath),
           let fileSize = fileAttributes[.size] as? Int64 {
            let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            print("Database Size: \(fileSizeString)")
        }

        print("Location Tracking: \(enableLocationTracking ? "Enabled" : "Disabled")")
        print("Logging: \(enableLogging ? "Enabled" : "Disabled")")
        print("Debug Mode: \(enableDebugMode ? "Enabled" : "Disabled")")
        print("==================================")
    }

    public func printAllTables() {
        print("===== Database Tables =====")
        do {
            let tables = try execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")

            if tables.isEmpty {
                print("No user tables found in database")
            } else {
                for (index, table) in tables.enumerated() {
                    if let tableName = table["name"] as? String {
                        print("\(index + 1). \(tableName)")
                        if enableDebugMode {
                            printTableInfo(tableName: tableName)
                        }
                    }
                }
            }
        } catch {
            print("Error fetching tables: \(error)")
        }
        print("==========================")
    }

    public func printTableInfo(tableName: String) {
        print("  ├─ Table: \(tableName)")

        do {
            // PRAGMA and FROM clauses do not support ? bindings for identifiers — table name is from our own schema.
            let columns = try execute("PRAGMA table_info(\(tableName))")
            print("  ├─ Columns:")
            for column in columns {
                let name = column["name"] as? String ?? "unknown"
                let type = column["type"] as? String ?? "unknown"
                let notNull = (column["notnull"] as? Int64) == 1 ? "NOT NULL" : ""
                let pk = (column["pk"] as? Int64) == 1 ? "PRIMARY KEY" : ""
                let defaultValue = column["dflt_value"] as? String ?? ""

                var columnInfo = "    ├─ \(name) \(type)"
                if !notNull.isEmpty { columnInfo += " \(notNull)" }
                if !pk.isEmpty { columnInfo += " \(pk)" }
                if !defaultValue.isEmpty { columnInfo += " DEFAULT \(defaultValue)" }

                print(columnInfo)
            }

            let countResult = try execute("SELECT COUNT(*) as count FROM \(tableName)")
            if let count = countResult.first?["count"] as? Int64 {
                print("  └─ Row Count: \(count)")
            }

        } catch {
            print("  └─ Error getting table info: \(error)")
        }
    }

    public func enableDetailedDebug() {
        enableDebugMode = true
        enableLocationTracking = true
        enableLogging = true

        print("Detailed Debug Mode Enabled")
        printDatabaseLocation()
        printAllTables()
    }
}
