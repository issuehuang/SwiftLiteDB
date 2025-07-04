#!/bin/bash

echo "🔧 應用最終修正..."

# 1. 確保測試檔案在正確位置
if [ -f "Sources/SwiftLiteDB/SwiftLiteDBTests.swift" ]; then
    echo "📁 移動測試檔案到正確位置..."
    mkdir -p Tests/SwiftLiteDBTests
    mv Sources/SwiftLiteDB/SwiftLiteDBTests.swift Tests/SwiftLiteDBTests/SwiftLiteDBTests.swift
fi

# 2. 修正 DBMigrator.swift 中的 Associated Objects 問題
echo "🔧 修正 DBMigrator.swift..."
cat > Sources/SwiftLiteDB/Migration/DBMigrator.swift << 'EOF'
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
extension SwiftLiteDB {
    private static let migratorKey = UnsafeRawPointer(bitPattern: "SwiftLiteDB.migrator".hashValue)!
    
    public var migrator: DBMigrator {
        if let existingMigrator = objc_getAssociatedObject(self, SwiftLiteDB.migratorKey) as? DBMigrator {
            return existingMigrator
        }
        
        let newMigrator = DBMigrator(db: self)
        objc_setAssociatedObject(self, SwiftLiteDB.migratorKey, newMigrator, .OBJC_ASSOCIATION_RETAIN)
        return newMigrator
    }
}
EOF

echo "✅ DBMigrator.swift 已修正"

# 3. 清理並編譯
echo "🧹 清理專案..."
rm -rf .build

echo "🔨 嘗試編譯..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功！"
    echo "🧪 執行測試..."
    swift test
    
    if [ $? -eq 0 ]; then
        echo "🎉 所有測試通過！"
        echo ""
        echo "🚀 SwiftLiteDB 套件已準備就緒！"
        echo ""
        echo "📋 接下來您可以："
        echo "   • 使用 'swift build' 編譯套件"
        echo "   • 使用 'swift test' 執行測試"
        echo "   • 將套件匯入到您的專案中"
    else
        echo "⚠️  測試有問題，但編譯成功"
    fi
else
    echo "❌ 編譯失敗，請檢查錯誤訊息"
    echo ""
    echo "🔍 使用 'swift build -v' 查看詳細錯誤"
fi

echo ""
echo "🏁 修正完成！"