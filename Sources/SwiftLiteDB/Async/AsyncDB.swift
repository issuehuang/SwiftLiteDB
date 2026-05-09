import Foundation

// A dedicated serial queue ensures database operations don't compete for threads
// while still running off the calling actor's executor.
private let dbAsyncQueue = DispatchQueue(label: "com.swiftlitedb.async", qos: .userInitiated)

// Box wraps non-Sendable types (e.g. [String: Any], [Any]) for safe cross-thread transfer.
// The NSRecursiveLock in SwiftLiteDB ensures actual thread safety.
private final class Box<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

extension SwiftLiteDB {

    // MARK: - Core async wrappers

    public func createTable(name: String, columns: [String], foreignKeys: [ForeignKey]? = nil) async throws {
        try await run { try self.createTable(name: name, columns: columns, foreignKeys: foreignKeys) }
    }

    public func insert(into table: String, values: [String: Any]) async throws {
        let boxedValues = Box(values)
        try await run { try self.insert(into: table, values: boxedValues.value) }
    }

    public func query(from table: String, where condition: String? = nil, parameters: [Any] = []) async throws -> [[String: Any]] {
        let boxedParams = Box(parameters)
        return try await run { try self.query(from: table, where: condition, parameters: boxedParams.value) }
    }

    public func execute(_ sql: String, parameters: [Any]? = nil) async throws -> [[String: Any]] {
        let boxedParams = Box(parameters)
        return try await run { try self.execute(sql, parameters: boxedParams.value) }
    }

    // MARK: - ORM async

    public func save<T: Model>(_ model: T) async throws -> T {
        try await run { try self.save(model) }
    }

    public func find<T: Model>(_ id: Int64, modelType: T.Type) async throws -> T? {
        try await run { try self.find(id, modelType: modelType) }
    }

    public func all<T: Model>(_ modelType: T.Type, where condition: String? = nil, parameters: [Any] = []) async throws -> [T] {
        let boxedParams = Box(parameters)
        return try await run { try self.all(modelType, where: condition, parameters: boxedParams.value) }
    }

    public func delete<T: Model>(_ model: T) async throws {
        try await run { try self.delete(model) }
    }

    // MARK: - Private

    private func run<T>(_ block: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            dbAsyncQueue.async {
                do {
                    continuation.resume(returning: try block())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
