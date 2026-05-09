# SwiftLiteDB

SwiftLiteDB 是一個輕量級的 Swift SQLite 封裝庫，提供簡單直觀的 API 來操作 SQLite 資料庫。無需編寫複雜的 SQL 語句，只需要幾行程式碼就能完成資料庫操作。

## ✨ 特點

- **簡單的 ORM** — 實作 `Model` 協定即可自動取得 CRUD 操作
- **原生 async/await** — 所有操作都有 `async throws` 版本，告別 callback hell
- **執行緒安全** — 透過 `NSRecursiveLock` 串行化，可從任何執行緒或 actor 安全呼叫
- **資料庫遷移** — 版本化 schema 變更，記錄於 `_migrations`，支援真正 transaction 保護的 rollback
- **Schema 輔助方法** — 內建 `addColumn`、`renameColumn`、`dropColumn`、`renameTable`、`createIndex`
- **Date & UUID 原生支援** — 自動以 ISO 8601 字串儲存與還原，無需手動轉換
- **參數化查詢** — 所有使用者輸入值皆透過 `?` 綁定，防止 SQL Injection
- **外鍵支援** — 在 Model 上宣告式定義 `ForeignKey`
- **調試工具** — `printDatabaseLocation()`、`printAllTables()`、`printTableInfo(tableName:)`

## 📋 系統需求

- iOS 13.0+ / macOS 10.15+
- Swift 5.0+（Swift 6 相容）
- Xcode 13+

## 📦 安裝

### Swift Package Manager

在 `Package.swift` 中加入：

```swift
dependencies: [
    .package(url: "https://github.com/issuehuang/SwiftLiteDB.git", from: "1.0.0")
]
```

或在 Xcode 中：**File → Add Package Dependencies**，輸入套件 URL。

---

## 🚀 快速開始

```swift
import SwiftLiteDB

let db = try SwiftLiteDB(name: "MyApp")
```

### 基本資料表操作

```swift
try db.createTable(name: "users", columns: [
    "id INTEGER PRIMARY KEY AUTOINCREMENT",
    "name TEXT NOT NULL",
    "age INTEGER"
])

// 值永遠透過 ? 綁定，不使用字串插值
try db.insert(into: "users", values: ["name": "Alice", "age": 30])

let rows   = try db.query(from: "users")
let adults = try db.query(from: "users", where: "age >= ?", parameters: [18])
```

---

## 🎯 ORM

### 定義模型

```swift
struct User: Model {
    static let tableName = "users"
    static let columns: [String: String] = [
        "id":         "INTEGER PRIMARY KEY AUTOINCREMENT",
        "username":   "TEXT NOT NULL UNIQUE",
        "email":      "TEXT NOT NULL",
        "created_at": "TEXT"        // Date 以 ISO 8601 儲存
    ]

    var id: Int64?
    var username: String
    var email: String
    var createdAt: Date?            // 自動編碼 / 解碼
}

struct Post: Model {
    static let tableName = "posts"
    static let columns: [String: String] = [
        "id":      "INTEGER PRIMARY KEY AUTOINCREMENT",
        "user_id": "INTEGER NOT NULL",
        "title":   "TEXT NOT NULL",
        "content": "TEXT"
    ]
    static var foreignKeys: [ForeignKey]? {
        [ForeignKey(column: "user_id", referenceTable: "users", referenceColumn: "id")]
    }

    var id: Int64?
    var userId: Int64
    var title: String
    var content: String?
}
```

### CRUD 操作

```swift
// 建立資料表
try db.createTable(for: User.self)
try db.createTable(for: Post.self)

// 新增
var user = User(id: nil, username: "alice", email: "alice@example.com", createdAt: Date())
user = try db.save(user)   // user.id 已自動設定

// 查詢
let found   = try db.find(user.id!, modelType: User.self)
let all     = try db.all(User.self)

// 參數化 WHERE — 使用者資料請務必用 ?
let matches = try db.all(User.self, where: "username = ?", parameters: ["alice"])

// 更新
user.email = "new@example.com"
user = try db.save(user)

// 刪除
try db.delete(user)
```

### Date 與 UUID 支援

`Date` 和 `UUID` 屬性自動序列化，無需手動轉換：

```swift
struct Task: Model {
    static let tableName = "tasks"
    static let columns: [String: String] = [
        "id":        "INTEGER PRIMARY KEY AUTOINCREMENT",
        "task_id":   "TEXT NOT NULL",   // UUID 以字串儲存
        "title":     "TEXT NOT NULL",
        "due_date":  "TEXT",            // Date 以 ISO 8601 儲存
        "completed": "INTEGER NOT NULL DEFAULT 0"
    ]

    var id: Int64?
    var taskId: UUID     // 自動存為 UUID 字串，讀取時自動還原
    var title: String
    var dueDate: Date?   // 自動存為 ISO 8601 字串，讀取時自動還原
    var completed: Bool
}
```

---

## ⚡ 非同步操作（async/await）

所有操作都有原生 `async throws` 版本，不再需要 completion handler：

```swift
// 基本操作
try await db.insert(into: "logs", values: ["message": "started"])

// ORM
var user = User(id: nil, username: "bob", email: "bob@example.com", createdAt: Date())
user = try await db.save(user)

let all    = try await db.all(User.self)
let single = try await db.find(user.id!, modelType: User.self)
try await db.delete(user)

// 自訂 SQL
let rows = try await db.execute("SELECT * FROM users WHERE age > ?", parameters: [18])
```

---

## 📈 資料庫遷移

### 定義遷移

```swift
struct CreateUsersMigration: Migration {
    var version = "001"
    var name    = "create_users_table"

    func up(_ db: SwiftLiteDB) throws {
        try db.createTable(for: User.self)
    }
    func down(_ db: SwiftLiteDB) throws {
        _ = try db.execute("DROP TABLE IF EXISTS users")
    }
}

struct AddAvatarMigration: Migration {
    var version = "002"
    var name    = "add_avatar_column"

    func up(_ db: SwiftLiteDB) throws {
        try db.addColumn(to: "users", name: "avatar_url", type: "TEXT")
    }
    func down(_ db: SwiftLiteDB) throws {
        try db.dropColumn(from: "users", name: "avatar_url")  // 需 iOS 15+ / SQLite 3.35+
    }
}

struct AddEmailIndexMigration: Migration {
    var version = "003"
    var name    = "add_email_index"

    func up(_ db: SwiftLiteDB) throws {
        try db.createIndex(name: "idx_users_email", on: "users", columns: ["email"], unique: true)
    }
    func down(_ db: SwiftLiteDB) throws {
        try db.dropIndex(name: "idx_users_email")
    }
}
```

### 執行遷移

```swift
let migrations: [Migration] = [
    CreateUsersMigration(),
    AddAvatarMigration(),
    AddEmailIndexMigration()
]

try db.migrator.migrate(migrations: migrations)
```

### Rollback

Rollback 會以相反順序執行 `down()`，每個步驟都包在 transaction 中，任何步驟失敗時資料庫保持不變：

```swift
// 回滾到 "001"（即還原 "003" 和 "002"，按倒序執行）
try db.migrator.rollback(to: "001", using: migrations)
```

### 遷移歷史

```swift
let history = try db.migrator.getMigrationHistory()
for entry in history {
    print("\(entry["version"]!) — \(entry["name"]!)")
}
```

---

## 🔧 Schema 輔助方法

在 `Migration.up()` / `Migration.down()` 中使用，無需自己寫 DDL：

| 方法 | 最低 SQLite 版本 |
|------|----------------|
| `addColumn(to:name:type:)` | 任意版本 |
| `renameTable(from:to:)` | 任意版本 |
| `renameColumn(in:from:to:)` | 3.25（iOS 13+）|
| `dropColumn(from:name:)` | 3.35（iOS 15+）|
| `createIndex(name:on:columns:unique:)` | 任意版本 |
| `dropIndex(name:)` | 任意版本 |

---

## 🔄 Transaction

遷移步驟自動在 transaction 中執行。自己的批次寫入也可使用：

```swift
try db.transaction { db in
    for item in items {
        try db.insert(into: "events", values: ["name": item.name])
    }
}
```

---

## 🐛 調試工具

```swift
db.enableLocationTracking = true
print(db.databasePath ?? "")        // .sqlite 檔案路徑

db.printDatabaseLocation()          // 大小、設定、路徑
db.printAllTables()                 // 列出所有資料表
db.printTableInfo(tableName: "users")  // 欄位結構 + 資料筆數

// 一次啟用所有調試功能：
db.enableDetailedDebug()
```

---

## 🎨 錯誤處理

```swift
do {
    let user = try db.find(999, modelType: User.self)
} catch SwiftLiteDBError.databaseNotInitialized {
    print("資料庫尚未初始化")
} catch SwiftLiteDBError.migrationNotFound {
    print("找不到指定的遷移版本")
} catch {
    print("未知錯誤：\(error)")
}
```

---

## 🤝 貢獻指南

歡迎提交 Pull Request 或建立 Issue！

```bash
git clone https://github.com/issuehuang/SwiftLiteDB.git
cd SwiftLiteDB
swift build
swift test
```

## 📄 授權

本專案採用 MIT 授權。詳情請見 [LICENSE](LICENSE)。

## 🙏 致謝

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift) — 底層 SQLite Swift 綁定

---

---

# SwiftLiteDB (English)

A lightweight Swift wrapper around SQLite, providing a simple and intuitive API for common database operations without writing raw SQL.

## Features

- **Simple ORM** — conform to `Model` and get CRUD for free
- **Native async/await** — all operations available as `async throws`; no callback hell
- **Thread-safe** — serialized via `NSRecursiveLock`; safe to call from any thread or actor
- **Migrations** — versioned schema changes tracked in `_migrations`, with real transaction-backed rollback
- **Schema helpers** — `addColumn`, `renameColumn`, `dropColumn`, `renameTable`, `createIndex` built-in
- **Date & UUID support** — stored as ISO 8601 strings and round-tripped automatically
- **Parameterized queries** — all user-supplied values bound via `?`, preventing SQL injection
- **Foreign keys** — declarative `ForeignKey` definitions on your model
- **Debug utilities** — `printDatabaseLocation()`, `printAllTables()`, `printTableInfo(tableName:)`

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.0+ (Swift 6 compatible)
- Xcode 13+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/issuehuang/SwiftLiteDB.git", from: "1.0.0")
]
```

## Quick Start

```swift
let db = try SwiftLiteDB(name: "MyApp")

// Values are always bound with ?, never interpolated
try db.insert(into: "users", values: ["name": "Alice", "age": 30])
let adults = try db.query(from: "users", where: "age >= ?", parameters: [18])
```

## ORM

```swift
struct User: Model {
    static let tableName = "users"
    static let columns: [String: String] = [
        "id":       "INTEGER PRIMARY KEY AUTOINCREMENT",
        "username": "TEXT NOT NULL",
        "due_date": "TEXT"   // Date stored as ISO 8601
    ]
    var id: Int64?
    var username: String
    var dueDate: Date?       // encoded/decoded automatically
}

try db.createTable(for: User.self)
var user = User(id: nil, username: "alice", dueDate: Date())
user = try db.save(user)
let found = try db.find(user.id!, modelType: User.self)
let all   = try db.all(User.self, where: "username = ?", parameters: ["alice"])
try db.delete(user)
```

## Async/Await

```swift
user = try await db.save(user)
let all = try await db.all(User.self)
```

## Migrations

```swift
struct AddAvatarMigration: Migration {
    var version = "002"
    var name    = "add_avatar_column"
    func up(_ db: SwiftLiteDB) throws   { try db.addColumn(to: "users", name: "avatar_url", type: "TEXT") }
    func down(_ db: SwiftLiteDB) throws { try db.dropColumn(from: "users", name: "avatar_url") }
}

try db.migrator.migrate(migrations: migrations)
try db.migrator.rollback(to: "001", using: migrations)
```

## License

MIT. See [LICENSE](LICENSE).
