import Foundation

/// A wrapper to make a non-Sendable type explicitly Sendable.
/// Use with caution, only when you can manually guarantee thread safety.
struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
}

extension SwiftLiteDB {
    // 基礎的異步執行器 (保持不變)
    public func asyncExecute(
        _ block: @escaping @Sendable () throws -> Void,
        queue: DispatchQueue = DispatchQueue.global(qos: .background),
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        queue.async {
            do {
                try block()
                DispatchQueue.main.async {
                    completion?(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
    }
    
    public func asyncExecute<T>(
        _ block: @escaping @Sendable () throws -> T,
        queue: DispatchQueue = DispatchQueue.global(qos: .background),
        completion: @escaping @Sendable (Result<T, Error>) -> Void
    ) {
        queue.async {
            do {
                let result = try block()
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // =============================================
    // 以下是所有使用 UncheckedSendable 包裝器的 ...Async 函式
    // =============================================
    
    // Async version of createTable
    public func createTableAsync(
        name: String,
        columns: [String],
        foreignKeys: [ForeignKey]? = nil,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let db = self
        // ForeignKey 等自定義類型也可能需要包裝，但我們先假設它們是 Sendable 的
        asyncExecute { [name, columns, foreignKeys] in
            try db.createTable(name: name, columns: columns, foreignKeys: foreignKeys)
        } completion: { error in
            completion?(error)
        }
    }
    
    // Async version of insert
    public func insertAsync(
        into table: String,
        values: [String: Any],
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let db = self
        let sendableValues = UncheckedSendable(value: values)
        let sendableTable = UncheckedSendable(value: table)
        
        asyncExecute {
            try db.insert(into: sendableTable.value, values: sendableValues.value)
        } completion: { error in
            completion?(error)
        }
    }
    
    // Async version of query
    public func queryAsync(
        from table: String,
        where condition: String? = nil,
        completion: @escaping @Sendable (Result<[[String: Any]], Error>) -> Void
    ) {
        let db = self
        let sendableTable = UncheckedSendable(value: table)
        let sendableCondition = UncheckedSendable(value: condition)

        asyncExecute {
            try db.query(from: sendableTable.value, where: sendableCondition.value)
        } completion: { result in
            completion(result)
        }
    }
    
    // Async version of execute
    public func executeAsync(
        _ sql: String,
        parameters: [Any]? = nil,
        completion: @escaping @Sendable (Result<[[String: Any]], Error>) -> Void
    ) {
        let db = self
        let sendableSql = UncheckedSendable(value: sql)
        let sendableParameters = UncheckedSendable(value: parameters)

        asyncExecute {
            try db.execute(sendableSql.value, parameters: sendableParameters.value)
        } completion: { result in
            completion(result)
        }
    }
    
    // Async ORM methods
    // 假設 Model, T, T.Type 都是 Sendable 的
    public func saveAsync<T: Model>(
        _ model: T,
        completion: @escaping @Sendable (Result<T, Error>) -> Void
    ) {
        let db = self
        asyncExecute { [model] in
            try db.save(model)
        } completion: { result in
            completion(result)
        }
    }
    
    public func findAsync<T: Model>(
        _ id: Int64,
        modelType: T.Type,
        completion: @escaping @Sendable (Result<T?, Error>) -> Void
    ) {
        let db = self
        asyncExecute { [id, modelType] in
            try db.find(id, modelType: modelType)
        } completion: { result in
            completion(result)
        }
    }
    
    public func allAsync<T: Model>(
        _ modelType: T.Type,
        where condition: String? = nil,
        completion: @escaping @Sendable (Result<[T], Error>) -> Void
    ) {
        let db = self
        let sendableCondition = UncheckedSendable(value: condition)
        asyncExecute { [modelType] in
            try db.all(modelType, where: sendableCondition.value)
        } completion: { result in
            completion(result)
        }
    }
    
    public func deleteAsync<T: Model>(
        _ model: T,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let db = self
        asyncExecute { [model] in
            try db.delete(model)
        } completion: { error in
            completion?(error)
        }
    }
}