# SwiftLiteDB

SwiftLiteDB 是一個輕量級的 Swift SQLite 封裝庫，提供簡單直觀的 API 來操作 SQLite 資料庫。無需編寫複雜的 SQL 語句，只需要幾行程式碼就能完成資料庫操作。

## ✨ 特點

- 🚀 **簡單直觀的 API** - 無需複雜的 SQL 知識
- 📦 **自動建立資料表** - 從 Swift 模型自動生成資料表
- 🔗 **簡化的外鍵設定** - 輕鬆建立表格關聯
- 🔍 **內建資料庫位置追蹤** - 方便開發調試
- ⚡️ **支援非同步操作** - 不阻塞主線程
- 🗃️ **物件關聯映射 (ORM)** - 直接使用 Swift 物件操作資料庫
- 📈 **資料庫遷移系統** - 管理資料庫結構版本控制
- 🐛 **強大的調試功能** - 快速定位和解決問題

## 📋 系統需求

- iOS 13.0+ / macOS 10.15+
- Swift 5.0+
- Xcode 11.0+

## 📦 安裝

### Swift Package Manager

將以下內容添加到您的 `Package.swift` 文件中：

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftLiteDB.git", from: "1.0.0")
]
```

或在 Xcode 中：
1. File → Add Package Dependencies
2. 輸入套件 URL：`https://github.com/yourusername/SwiftLiteDB.git`
3. 點擊 Add Package

## 🚀 快速開始

### 初始化資料庫

```swift
import SwiftLiteDB

// 創建資料庫實例
let db = try SwiftLiteDB(name: "MyApp")

// 開啟資料庫位置追蹤（選用）
db.enableLocationTracking = true
print(db.databasePath) // 輸出資料庫檔案位置
```

### 基本操作

```swift
// 建立資料表
let userColumns = ["id INTEGER PRIMARY KEY", 
                  "name TEXT NOT NULL",
                  "age INTEGER"]

try db.createTable(name: "users", columns: userColumns)

// 插入資料
try db.insert(into: "users", values: [
    "name": "John",
    "age": 25
])

// 查詢資料
let users = try db.query(from: "users")
let youngUsers = try db.query(from: "users", where: "age < 30")
```

## 🎯 核心功能

### 1. 物件關聯映射 (ORM)

#### 定義模型

```swift
struct User: Model {
    static let tableName = "users"
    static let columns = [
        "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
        "username": "TEXT NOT NULL UNIQUE",
        "email": "TEXT NOT NULL UNIQUE",
        "created_at": "DATETIME DEFAULT CURRENT_TIMESTAMP"
    ]
    
    var id: Int64?
    var username: String
    var email: String
    var createdAt: Date?
}

struct Post: Model {
    static let tableName = "posts"
    static let columns = [
        "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
        "user_id": "INTEGER NOT NULL",
        "title": "TEXT NOT NULL",
        "content": "TEXT"
    ]
    
    static var foreignKeys: [ForeignKey]? {
        return [
            ForeignKey(column: "user_id", 
                      referenceTable: "users", 
                      referenceColumn: "id")
        ]
    }
    
    var id: Int64?
    var userId: Int64
    var title: String
    var content: String?
}
```

#### 使用模型

```swift
// 自動建立資料表
try db.createTable(for: User.self)
try db.createTable(for: Post.self)

// 新增使用者
var user = User(id: nil, username: "john_doe", email: "john@example.com", createdAt: nil)
user = try db.save(user)
print("使用者已儲存，ID: \(user.id!)")

// 查詢使用者
if let foundUser = try db.find(1, modelType: User.self) {
    print("找到使用者: \(foundUser.username)")
}

// 查詢所有使用者
let allUsers = try db.all(User.self)
let admins = try db.all(User.self, where: "username LIKE '%admin%'")

// 新增文章
var post = Post(id: nil, userId: user.id!, title: "Hello World", content: "My first post")
post = try db.save(post)

// 刪除使用者
try db.delete(user)
```

### 2. 非同步操作

```swift
// 非同步新增使用者
let newUser = User(id: nil, username: "jane_doe", email: "jane@example.com", createdAt: nil)
db.saveAsync(newUser) { result in
    switch result {
    case .success(let user):
        print("使用者已儲存，ID: \(user.id!)")
    case .failure(let error):
        print("儲存使用者錯誤: \(error)")
    }
}

// 非同步查詢所有使用者
db.allAsync(User.self) { result in
    switch result {
    case .success(let users):
        print("總共有 \(users.count) 位使用者")
        for user in users {
            print("- \(user.username)")
        }
    case .failure(let error):
        print("查詢使用者錯誤: \(error)")
    }
}

// 非同步查詢
db.queryAsync(from: "users", where: "age > 18") { result in
    switch result {
    case .success(let users):
        print("找到 \(users.count) 位成年使用者")
    case .failure(let error):
        print("查詢錯誤: \(error)")
    }
}
```

### 3. 資料庫遷移

#### 定義遷移

```swift
struct CreateUsersMigration: Migration {
    var version: String = "2025_01_01_001"
    var name: String = "create_users_table"
    
    func up(_ db: SwiftLiteDB) throws {
        try db.createTable(for: User.self)
    }
    
    func down(_ db: SwiftLiteDB) throws {
        _ = try db.execute("DROP TABLE IF EXISTS users")
    }
}

struct CreatePostsMigration: Migration {
    var version: String = "2025_01_01_002"
    var name: String = "create_posts_table"
    
    func up(_ db: SwiftLiteDB) throws {
        try db.createTable(for: Post.self)
    }
    
    func down(_ db: SwiftLiteDB) throws {
        _ = try db.execute("DROP TABLE IF EXISTS posts")
    }
}

struct AddUserAvatarMigration: Migration {
    var version: String = "2025_01_02_001"
    var name: String = "add_user_avatar_column"
    
    func up(_ db: SwiftLiteDB) throws {
        _ = try db.execute("ALTER TABLE users ADD COLUMN avatar_url TEXT")
    }
    
    func down(_ db: SwiftLiteDB) throws {
        // SQLite 不支援 DROP COLUMN，需要重建表格
        _ = try db.execute("ALTER TABLE users DROP COLUMN avatar_url")
    }
}
```

#### 執行遷移

```swift
// 註冊所有遷移
let migrations: [Migration] = [
    CreateUsersMigration(),
    CreatePostsMigration(),
    AddUserAvatarMigration()
]

// 執行遷移
try db.migrator.migrate(migrations: migrations)

// 查詢遷移歷史
let migrationHistory = try db.migrator.getMigrationHistory()
for migration in migrationHistory {
    print("\(migration["version"] as? String ?? "") - \(migration["name"] as? String ?? "")")
}
```

### 4. 調試功能

```swift
// 開啟詳細調試模式（會自動印出所有資訊）
db.enableDetailedDebug()

// 印出資料庫位置和基本資訊
db.printDatabaseLocation()
// 輸出：
// ===== SwiftLiteDB Debug Info =====
// Database Name: MyApp
// Database Path: /Users/.../Documents/MyApp.sqlite
// Database exists: true
// Database Size: 245 KB
// Location Tracking: Enabled
// Logging: Enabled
// Debug Mode: Enabled
// ==================================

// 印出所有資料表
db.printAllTables()

// 印出特定資料表的詳細資訊
db.printTableInfo(tableName: "users")
// 輸出：
//   ├─ Table: users
//   ├─ Columns:
//     ├─ id INTEGER NOT NULL PRIMARY KEY
//     ├─ username TEXT NOT NULL
//     ├─ email TEXT NOT NULL
//   └─ Row Count: 25
```

## 💡 實際應用範例

### 完整的部落格應用

```swift
import SwiftLiteDB

class BlogService {
    private let db: SwiftLiteDB
    
    init() throws {
        // 初始化資料庫
        db = try SwiftLiteDB(name: "BlogApp")
        
        #if DEBUG
        db.enableDetailedDebug()
        #endif
        
        // 執行遷移
        try setupDatabase()
    }
    
    private func setupDatabase() throws {
        let migrations: [Migration] = [
            CreateUsersMigration(),
            CreatePostsMigration()
        ]
        
        try db.migrator.migrate(migrations: migrations)
    }
    
    // MARK: - 使用者操作
    
    func createUser(username: String, email: String) throws -> User {
        var user = User(id: nil, username: username, email: email, createdAt: nil)
        user = try db.save(user)
        return user
    }
    
    func findUser(username: String) throws -> User? {
        let users = try db.all(User.self, where: "username = '\(username)'")
        return users.first
    }
    
    func getAllUsers() throws -> [User] {
        return try db.all(User.self)
    }
    
    // MARK: - 文章操作
    
    func createPost(userId: Int64, title: String, content: String) throws -> Post {
        var post = Post(id: nil, userId: userId, title: title, content: content)
        post = try db.save(post)
        return post
    }
    
    func getPostsByUser(userId: Int64) throws -> [Post] {
        return try db.all(Post.self, where: "user_id = \(userId)")
    }
    
    func getRecentPosts(limit: Int = 10) throws -> [Post] {
        let results = try db.execute("""
            SELECT * FROM posts 
            ORDER BY id DESC 
            LIMIT ?
        """, parameters: [limit])
        
        return try results.map { try Post.fromDictionary($0) }
    }
    
    func searchPosts(keyword: String) throws -> [Post] {
        let results = try db.execute("""
            SELECT * FROM posts 
            WHERE title LIKE ? OR content LIKE ?
            ORDER BY id DESC
        """, parameters: ["%\(keyword)%", "%\(keyword)%"])
        
        return try results.map { try Post.fromDictionary($0) }
    }
    
    // MARK: - 複雜查詢
    
    func getUsersWithPostCount() throws -> [[String: Any]] {
        return try db.execute("""
            SELECT 
                u.id,
                u.username,
                u.email,
                COUNT(p.id) as post_count
            FROM users u
            LEFT JOIN posts p ON u.id = p.user_id
            GROUP BY u.id, u.username, u.email
            ORDER BY post_count DESC
        """)
    }
    
    // MARK: - 非同步操作
    
    func createUserAsync(username: String, email: String, completion: @escaping (Result<User, Error>) -> Void) {
        let user = User(id: nil, username: username, email: email, createdAt: nil)
        
        db.saveAsync(user) { result in
            completion(result)
        }
    }
    
    func getRecentPostsAsync(limit: Int = 10, completion: @escaping (Result<[Post], Error>) -> Void) {
        db.executeAsync("""
            SELECT * FROM posts 
            ORDER BY id DESC 
            LIMIT ?
        """, parameters: [limit]) { result in
            switch result {
            case .success(let rows):
                do {
                    let posts = try rows.map { try Post.fromDictionary($0) }
                    completion(.success(posts))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - 使用範例

func exampleUsage() {
    do {
        let blogService = try BlogService()
        
        // 創建使用者
        let user = try blogService.createUser(username: "john_doe", email: "john@example.com")
        print("創建使用者: \(user.username) (ID: \(user.id!))")
        
        // 創建文章
        let post = try blogService.createPost(
            userId: user.id!,
            title: "SwiftLiteDB 使用心得",
            content: "這個 SQLite 封裝庫真的很好用，推薦給大家！"
        )
        print("創建文章: \(post.title)")
        
        // 查詢使用者的所有文章
        let userPosts = try blogService.getPostsByUser(userId: user.id!)
        print("使用者有 \(userPosts.count) 篇文章")
        
        // 搜尋文章
        let searchResults = try blogService.searchPosts(keyword: "SwiftLiteDB")
        print("搜尋結果: \(searchResults.count) 篇文章")
        
        // 取得使用者及其文章數量
        let usersWithPostCount = try blogService.getUsersWithPostCount()
        for userInfo in usersWithPostCount {
            let username = userInfo["username"] as? String ?? "Unknown"
            let postCount = userInfo["post_count"] as? Int64 ?? 0
            print("\(username): \(postCount) 篇文章")
        }
        
    } catch {
        print("錯誤: \(error)")
    }
}

// 非同步使用範例
func asyncExampleUsage() {
    do {
        let blogService = try BlogService()
        
        // 非同步創建使用者
        blogService.createUserAsync(username: "jane_doe", email: "jane@example.com") { result in
            switch result {
            case .success(let user):
                print("非同步創建使用者: \(user.username)")
                
                // 非同步取得最近文章
                blogService.getRecentPostsAsync(limit: 5) { result in
                    switch result {
                    case .success(let posts):
                        print("取得 \(posts.count) 篇最近文章")
                        for post in posts {
                            print("- \(post.title)")
                        }
                    case .failure(let error):
                        print("取得文章錯誤: \(error)")
                    }
                }
                
            case .failure(let error):
                print("創建使用者錯誤: \(error)")
            }
        }
        
    } catch {
        print("初始化錯誤: \(error)")
    }
}
```

### 待辦事項應用

```swift
struct Task: Model {
    static let tableName = "tasks"
    static let columns = [
        "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
        "title": "TEXT NOT NULL",
        "description": "TEXT",
        "completed": "BOOLEAN DEFAULT 0",
        "due_date": "DATETIME",
        "created_at": "DATETIME DEFAULT CURRENT_TIMESTAMP"
    ]
    
    var id: Int64?
    var title: String
    var description: String?
    var completed: Bool
    var dueDate: Date?
    var createdAt: Date?
}

class TaskManager {
    private let db: SwiftLiteDB
    
    init() throws {
        db = try SwiftLiteDB(name: "TaskApp")
        try db.createTable(for: Task.self)
    }
    
    func addTask(title: String, description: String?, dueDate: Date?) throws -> Task {
        var task = Task(id: nil, title: title, description: description, 
                       completed: false, dueDate: dueDate, createdAt: nil)
        task = try db.save(task)
        return task
    }
    
    func completeTask(_ task: Task) throws -> Task {
        var updatedTask = task
        updatedTask.completed = true
        return try db.save(updatedTask)
    }
    
    func getPendingTasks() throws -> [Task] {
        return try db.all(Task.self, where: "completed = 0")
    }
    
    func getOverdueTasks() throws -> [Task] {
        let now = Date().timeIntervalSince1970
        return try db.all(Task.self, where: "completed = 0 AND due_date < \(now)")
    }
}
```

## 🔧 進階功能

### 批次操作

```swift
try db.transaction { db in
    for i in 1...100 {
        try db.insert(into: "logs", values: [
            "message": "Log entry \(i)",
            "level": "INFO"
        ])
    }
}
```

### 自訂 SQL 查詢

```swift
let complexQuery = """
    SELECT u.username, COUNT(p.id) as post_count
    FROM users u
    LEFT JOIN posts p ON u.id = p.user_id
    GROUP BY u.id
    HAVING post_count > ?
    ORDER BY post_count DESC
"""

let activeUsers = try db.execute(complexQuery, parameters: [5])
```

### 資料庫統計

```swift
// 取得資料庫統計資訊
db.printDatabaseStats()
// 輸出：
// ===== Database Statistics =====
// File Size: 245 KB
// Page Count: 1024
// Page Size: 4096 bytes
// Free Pages: 10
// Total Tables: 5
// Total Rows: 1250
// ==============================
```

## 🎨 最佳實務

### 1. 錯誤處理

```swift
do {
    let user = try db.find(1, modelType: User.self)
    // 處理使用者
} catch SwiftLiteDBError.databaseNotInitialized {
    print("資料庫未初始化")
} catch SwiftLiteDBError.invalidModelDefinition {
    print("模型定義無效")
} catch {
    print("未知錯誤: \(error)")
}
```

### 2. 效能優化

```swift
// 使用交易進行批次操作
try db.transaction { db in
    for user in users {
        try db.save(user)
    }
}

// 為常用查詢建立索引
_ = try db.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")
_ = try db.execute("CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id)")
```

### 3. 記憶體管理

```swift
// 在背景處理大量資料
db.allAsync(User.self) { result in
    switch result {
    case .success(let users):
        // 在主線程更新 UI
        DispatchQueue.main.async {
            self.updateUI(with: users)
        }
    case .failure(let error):
        print("錯誤: \(error)")
    }
}
```

## 🤝 貢獻指南

歡迎提交 Pull Request 或建立 Issue 來改善這個專案！

### 開發設定

```bash
# 複製專案
git clone https://github.com/yourusername/SwiftLiteDB.git
cd SwiftLiteDB

# 建置專案
swift build

# 執行測試
swift test
```

### 提交前檢查

1. 確保所有測試通過
2. 更新相關文件
3. 遵循現有的程式碼風格
4. 添加新功能的測試案例

## 📄 授權

本專案採用 MIT 授權。詳情請見 [LICENSE](LICENSE) 文件。

## 🙏 致謝

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift) - 優秀的 SQLite Swift 綁定
- Swift 社群的支持和貢獻

## 📞 聯絡方式

如有任何問題或建議，歡迎：

- 建立 [Issue](https://github.com/yourusername/SwiftLiteDB/issues)
- 發送 [Pull Request](https://github.com/yourusername/SwiftLiteDB/pulls)
- 聯絡作者：[your.email@example.com]

---

**SwiftLiteDB** - 讓 SQLite 在 Swift 中變得簡單易用！ 🚀