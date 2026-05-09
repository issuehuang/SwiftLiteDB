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

        for migration in migrations.sorted(by: Self.versionLessThan) {
            if try !isMigrationApplied(version: migration.version) {
                try db.transaction { db in
                    try migration.up(db)
                    try self.recordMigration(version: migration.version, name: migration.name)
                }

                if db.enableLogging {
                    print("Applied migration: \(migration.version) - \(migration.name)")
                }
            }
        }
    }

    /// Roll back all migrations applied after `version`, executing `down()` in reverse order.
    /// - Parameters:
    ///   - version: The target version to roll back TO (this version stays applied).
    ///   - migrations: The full list of known migrations (needed to call `down()`).
    public func rollback(to version: String, using migrations: [Migration]) throws {
        let history = try getMigrationHistory()
        let appliedVersions = history.compactMap { $0["version"] as? String }

        guard let targetIndex = appliedVersions.firstIndex(of: version) else {
            throw SwiftLiteDBError.migrationNotFound
        }

        // Versions applied after the target, in reverse order (newest first)
        let versionsToRollback = Array(appliedVersions[(targetIndex + 1)...].reversed())
        let migrationsByVersion = Dictionary(uniqueKeysWithValues: migrations.map { ($0.version, $0) })

        for ver in versionsToRollback {
            guard let migration = migrationsByVersion[ver] else { continue }
            try db.transaction { db in
                try migration.down(db)
                _ = try db.execute(
                    "DELETE FROM \(self.migrationTableName) WHERE version = ?",
                    parameters: [ver]
                )
            }
            if db.enableLogging {
                print("Rolled back migration: \(ver) - \(migration.name)")
            }
        }
    }

    public func getMigrationHistory() throws -> [[String: Any]] {
        return try db.query(from: migrationTableName)
    }

    // MARK: - Private

    private func isMigrationApplied(version: String) throws -> Bool {
        let result = try db.query(
            from: migrationTableName,
            where: "version = ?",
            parameters: [version]
        )
        return !result.isEmpty
    }

    private func recordMigration(version: String, name: String) throws {
        try db.insert(into: migrationTableName, values: [
            "version": version,
            "name": name
        ])
    }

    /// Sort versions numerically when possible, fall back to lexicographic.
    private static func versionLessThan(_ a: Migration, _ b: Migration) -> Bool {
        if let ia = Int(a.version), let ib = Int(b.version) {
            return ia < ib
        }
        return a.version < b.version
    }
}

// Extension to SwiftLiteDB to add migration capabilities
extension SwiftLiteDB {
    @MainActor
    private static var migratorKey: UInt8 = 0

    @MainActor
    public var migrator: DBMigrator {
        if let existingMigrator = objc_getAssociatedObject(self, &Self.migratorKey) as? DBMigrator {
            return existingMigrator
        }

        let newMigrator = DBMigrator(db: self)
        objc_setAssociatedObject(self, &Self.migratorKey, newMigrator, .OBJC_ASSOCIATION_RETAIN)
        return newMigrator
    }
}
