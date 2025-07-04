import XCTest
@testable import SwiftLiteDB

final class SwiftLiteDBTests: XCTestCase {
    var db: SwiftLiteDB!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 使用記憶體資料庫
        db = try SwiftLiteDB(name: ":memory:")
        db.enableLogging = true
        
        // 清理所有現有的表格，確保每個測試都是乾淨的狀態
        cleanupDatabase()
    }

    override func tearDownWithError() throws {
        cleanupDatabase() // 測試後也清理一次
        db = nil
        try super.tearDownWithError()
    }
    
    // 清理資料庫的輔助方法
    private func cleanupDatabase() {
        do {
            // 獲取所有用戶表格並刪除（保留系統表格）
            let tables = try db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            for table in tables {
                if let tableName = table["name"] as? String {
                    _ = try db.execute("DROP TABLE IF EXISTS \(tableName)")
                }
            }
        } catch {
            // 在測試設定階段，可能還沒有任何表格，這是正常的
            print("清理資料庫時發生錯誤: \(error)")
        }
    }

    func testCreateTable() throws {
        try db.createTable(name: "test_users",
                           columns: ["id INTEGER PRIMARY KEY", "name TEXT"])
    }

    func testInsertAndQuery() throws {
        try db.createTable(name: "test_users",
                           columns: ["id INTEGER PRIMARY KEY", "name TEXT"])
        try db.insert(into: "test_users", values: ["name": "John"])
        
        let results = try db.query(from: "test_users")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["name"] as? String, "John")
    }

    func testForeignKey() throws {
        try db.createTable(name: "test_users",
                           columns: ["id INTEGER PRIMARY KEY", "name TEXT"])
        try db.createTable(name: "test_orders",
                           columns: ["id INTEGER PRIMARY KEY", "user_id INTEGER"],
                           foreignKeys: [
                            ForeignKey(column: "user_id",
                                       referenceTable: "test_users",
                                       referenceColumn: "id")
                           ])
    }

    func testORM() throws {
        struct TestUser: Model {
            static let tableName = "test_orm_users"
            static let columns = [
                "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
                "name": "TEXT NOT NULL"
            ]
            static let primaryKey: String = "id"
            static let foreignKeys: [ForeignKey]? = nil
            var id: Int64?
            var name: String
        }

        try db.createTable(for: TestUser.self)
        var user = TestUser(id: nil, name: "John")
        user = try db.save(user)
        let allUsers = try db.all(TestUser.self)
        XCTAssertEqual(allUsers.count, 1)
    }

    func testDebugFunctions() throws {
        try db.createTable(name: "debug_test",
                           columns: ["id INTEGER PRIMARY KEY", "data TEXT"])
        try db.insert(into: "debug_test", values: ["data": "test"])

        db.printDatabaseLocation()
        db.printAllTables()
        db.printTableInfo(tableName: "debug_test")
    }
    
    @MainActor
    func testMigration() throws {
        struct TestMigration: Migration {
            var version: String = "2025_01_01_001"
            var name: String = "create_migration_test_table"
            func up(_ db: SwiftLiteDB) throws {
                try db.createTable(name: "migration_test",
                                   columns: ["id INTEGER PRIMARY KEY", "value TEXT"])
            }
            func down(_ db: SwiftLiteDB) throws {
                _ = try db.execute("DROP TABLE IF EXISTS migration_test")
            }
        }
        let migrations: [Migration] = [TestMigration()]
        try db.migrator.migrate(migrations: migrations)
        let tables = try db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='migration_test'")
        XCTAssertEqual(tables.count, 1)
    }

    func testAsync() {
        let expectation = XCTestExpectation(description: "Async operation completed")
        let database = self.db!
        
        do {
            try database.createTable(name: "async_test", 
                                   columns: ["id INTEGER PRIMARY KEY", "name TEXT"])
            database.insertAsync(into: "async_test", values: ["name": "AsyncTest"]) { error in
                if let error = error {
                    XCTFail("Async insert failed: \(error)")
                    expectation.fulfill()
                    return
                }
                database.queryAsync(from: "async_test") { result in
                    switch result {
                    case .success(let rows):
                        XCTAssertEqual(rows.count, 1)
                        XCTAssertEqual(rows[0]["name"] as? String, "AsyncTest")
                    case .failure(let error):
                        XCTFail("Async query failed: \(error)")
                    }
                    expectation.fulfill()
                }
            }
        } catch {
            XCTFail("Failed to setup async test: \(error)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
}