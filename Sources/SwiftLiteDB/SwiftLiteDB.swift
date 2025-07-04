import Foundation
import SQLite

public final class SwiftLiteDB: @unchecked Sendable {
    private var db: Connection?
    private let dbName: String
    private let dbPath: String
    
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
        
        var sql = "CREATE TABLE IF NOT EXISTS \(name) ("
        sql += columns.joined(separator: ", ")
        
        if let foreignKeys = foreignKeys, !foreignKeys.isEmpty {
            sql += ", "
            sql += foreignKeys.map { $0.sqlString() }.joined(separator: ", ")
        }
        
        sql += ")"
        
        if enableLogging {
            print("Executing SQL: \(sql)")
        }
        
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
        
        let bindingValues = values.values.compactMap { value -> Binding? in
            if let stringValue = value as? String {
                return stringValue
            } else if let intValue = value as? Int {
                return Int64(intValue)
            } else if let int64Value = value as? Int64 {
                return int64Value
            } else if let doubleValue = value as? Double {
                return doubleValue
            } else if let boolValue = value as? Bool {
                return boolValue
            } else if value is NSNull {
                return nil
            }
            return nil
        }
        
        try db.run(sql, bindingValues)
    }
    
    public func query(from table: String, where condition: String? = nil) throws -> [[String: Any]] {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }
        
        var sql = "SELECT * FROM \(table)"
        if let condition = condition {
            sql += " WHERE \(condition)"
        }
        
        if enableLogging {
            print("Executing SQL: \(sql)")
        }
        
        var results: [[String: Any]] = []
        let statement = try db.prepare(sql)
        
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
        
        try db.transaction {
            try block(self)
        }
    }
    
    public func execute(_ sql: String, parameters: [Any]? = nil) throws -> [[String: Any]] {
        guard let db = db else { throw SwiftLiteDBError.databaseNotInitialized }
        
        if enableLogging {
            print("Executing SQL: \(sql)")
            if let parameters = parameters {
                print("With parameters: \(parameters)")
            }
        }
        
        let bindingParams = parameters?.compactMap { param -> Binding? in
            if let stringValue = param as? String {
                return stringValue
            } else if let intValue = param as? Int {
                return Int64(intValue)
            } else if let int64Value = param as? Int64 {
                return int64Value
            } else if let doubleValue = param as? Double {
                return doubleValue
            } else if let boolValue = param as? Bool {
                return boolValue
            }
            return nil
        } ?? []
        
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
    
    // MARK: - Debug Functions
    
    /// 印出資料庫位置和基本資訊
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
    
    /// 取得資料庫中所有資料表資訊
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
                        
                        // 如果啟用 debug 模式，印出表格結構
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
    
    /// 印出特定資料表的詳細資訊
    public func printTableInfo(tableName: String) {
        print("  ├─ Table: \(tableName)")
        
        do {
            // 取得表格結構
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
            
            // 取得記錄數量
            let countResult = try execute("SELECT COUNT(*) as count FROM \(tableName)")
            if let count = countResult.first?["count"] as? Int64 {
                print("  └─ Row Count: \(count)")
            }
            
        } catch {
            print("  └─ Error getting table info: \(error)")
        }
    }
    
    /// 開啟詳細調試模式
    public func enableDetailedDebug() {
        enableDebugMode = true
        enableLocationTracking = true
        enableLogging = true
        
        print("🔍 Detailed Debug Mode Enabled")
        printDatabaseLocation()
        printAllTables()
    }
}