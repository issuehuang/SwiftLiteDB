import Foundation

public class DBMigrator {
    private let db: SwiftLiteDB
    private let migrationTableName = "_migrations"
    
    init(db: SwiftLiteDB) {
        self.db = db
    }
    
    public func setup() throws {
        try db.createTable(name: migrationTableName, columns: [
            "id INTEGER PRIMARY KEY AUTOINCREMENT",
            "version TEXT NOT NULL",
            "name TEXT NOT NULL",
            "applied_at DATETIME DEFAULT CURRENT_TIMESTAMP"
        ])
    }
    
    public func migrate(migrations: [Migration]) throws {
        try setup()
        
        for migration in migrations.sorted(by: { $0.version < $1.version }) {
            if try !isMigrationApplied(version: migration.version) {
                try db.transaction { db in
                    try migration.up(db)
                    try recordMigration(version: migration.version, name: migration.name)
                }
                
                if db.enableLogging {
                    print("Applied migration: \(migration.version) - \(migration.name)")
                }
            }
        }
    }
    
    private func isMigrationApplied(version: String) throws -> Bool {
        let result = try db.query(
            from: migrationTableName,
            where: "version = '\(version)'"
        )
        return !result.isEmpty
    }
    
    private func recordMigration(version: String, name: String) throws {
        try db.insert(into: migrationTableName, values: [
            "version": version,
            "name": name
        ])
    }
    
    public func getMigrationHistory() throws -> [[String: Any]] {
        return try db.query(from: migrationTableName, where: nil)
    }
    
    public func rollback(to version: String) throws {
        let history = try getMigrationHistory()
        let versions = history.compactMap { $0["version"] as? String }
        
        guard let index = versions.firstIndex(of: version) else {
            throw SwiftLiteDBError.migrationNotFound
        }
        
        let toRollback = versions[index+1..<versions.count]
        
        // Implementation of rollback logic would go here
        // This is a placeholder for future implementation
        print("Would rollback versions: \(toRollback)")
    }
}

// Extension to SwiftLiteDB to add migration capabilities
// Extension to SwiftLiteDB to add migration capabilities
extension SwiftLiteDB {
    @MainActor
    private static var migratorKey: UInt8 = 0
    
    @MainActor
    public var migrator: DBMigrator {
        // 使用 &migratorKey 來獲取這個靜態變數的穩定記憶體位址作為 key
        if let existingMigrator = objc_getAssociatedObject(self, &Self.migratorKey) as? DBMigrator {
            return existingMigrator
        }
        
        let newMigrator = DBMigrator(db: self)
        objc_setAssociatedObject(self, &Self.migratorKey, newMigrator, .OBJC_ASSOCIATION_RETAIN)
        return newMigrator
    }
}