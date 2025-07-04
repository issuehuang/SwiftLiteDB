import Foundation
import SwiftLiteDB

// MARK: - Model 定義範例

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
        "content": "TEXT",
        "created_at": "DATETIME DEFAULT CURRENT_TIMESTAMP"
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
    var createdAt: Date?
}

// MARK: - Migration 範例

struct CreateUsersMigration: Migration {
    var version: String = "2025_01_01_001"
    var name: String = "create_users_table"
    
    func up(_ db: SwiftLiteDB) throws {
        try db.createTable(for: User.self)
    }
    
    func down(_ db: SwiftLiteDB) throws {
        try db.execute("DROP TABLE IF EXISTS users")
    }
}

struct CreatePostsMigration: Migration {
    var version: String = "2025_01_01_002"
    var name: String = "create_posts_table"
    
    func up(_ db: SwiftLiteDB) throws {
        try db.createTable(for: Post.self)
    }
    
    func down(_ db: SwiftLiteDB) throws {
        try db.execute("DROP TABLE IF EXISTS posts")
    }
}

// MARK: - 使用範例

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
    
    func findUser(id: Int64) throws -> User? {
        return try db.find(id, modelType: User.self)
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
        var post = Post(id: nil, userId: userId, title: title, content: content, createdAt: nil)
        post = try db.save(post)
        return post
    }
    
    func getPostsByUser(userId: Int64) throws -> [Post] {
        return try db.all(Post.self, where: "user_id = \(userId)")
    }
    
    func getRecentPosts(limit: Int = 10) throws -> [Post] {
        let results = try db.execute("""
            SELECT * FROM posts 
            ORDER BY created_at DESC 
            LIMIT ?
        """, parameters: [limit])
        
        return try results.map { try Post.fromDictionary($0) }
    }
    
    // MARK: - 非同步操作範例
    
    func createUserAsync(username: String, email: String, completion: @escaping (Result<User, Error>) -> Void) {
        let user = User(id: nil, username: username, email: email, createdAt: nil)
        
        db.saveAsync(user) { result in
            completion(result)
        }
    }
    
    func getRecentPostsAsync(limit: Int = 10, completion: @escaping (Result<[Post], Error>) -> Void) {
        db.executeAsync("""
            SELECT * FROM posts 
            ORDER BY created_at DESC 
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
    
    // MARK: - 複雜查詢範例
    
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
    
    func searchPosts(keyword: String) throws -> [Post] {
        let results = try db.execute("""
            SELECT * FROM posts 
            WHERE title LIKE ? OR content LIKE ?
            ORDER BY created_at DESC
        """, parameters: ["%\(keyword)%", "%\(keyword)%"])
        
        return try results.map { try Post.fromDictionary($0) }
    }
}

// MARK: - 使用示例

func exampleUsage() {
    do {
        let blogService = try BlogService()
        
        // 創建使用者
        let user = try blogService.createUser(username: "john_doe", email: "john@example.com")
        print("Created user: \(user.username) with ID: \(user.id!)")
        
        // 創建文章
        let post = try blogService.createPost(
            userId: user.id!,
            title: "SwiftLiteDB 使用心得",
            content: "這個 SQLite 封裝庫真的很好用..."
        )
        print("Created post: \(post.title)")
        
        // 查詢使用者的所有文章
        let userPosts = try blogService.getPostsByUser(userId: user.id!)
        print("User has \(userPosts.count) posts")
        
        // 取得最近的文章
        let recentPosts = try blogService.getRecentPosts(limit: 5)
        print("Recent posts: \(recentPosts.count)")
        
        // 搜尋文章
        let searchResults = try blogService.searchPosts(keyword: "SwiftLiteDB")
        print("Search results: \(searchResults.count)")
        
        // 取得使用者及其文章數量
        let usersWithPostCount = try blogService.getUsersWithPostCount()
        for userInfo in usersWithPostCount {
            let username = userInfo["username"] as? String ?? "Unknown"
            let postCount = userInfo["post_count"] as? Int64 ?? 0
            print("\(username): \(postCount) posts")
        }
        
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - 非同步使用示例

func asyncExampleUsage() {
    do {
        let blogService = try BlogService()
        
        // 非同步創建使用者
        blogService.createUserAsync(username: "jane_doe", email: "jane@example.com") { result in
            switch result {
            case .success(let user):
                print("Async created user: \(user.username)")
                
                // 非同步取得最近文章
                blogService.getRecentPostsAsync(limit: 5) { result in
                    switch result {
                    case .success(let posts):
                        print("Async got \(posts.count) recent posts")
                    case .failure(let error):
                        print("Async error: \(error)")
                    }
                }
                
            case .failure(let error):
                print("Async create user error: \(error)")
            }
        }
        
    } catch {
        print("Setup error: \(error)")
    }
}