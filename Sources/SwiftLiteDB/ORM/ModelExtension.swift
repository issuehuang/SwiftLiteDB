import Foundation

extension SwiftLiteDB {
    public func createTable<T: Model>(for modelType: T.Type) throws {
        let columns = modelType.columns.map { key, type in
            "\(key) \(type)"
        }

        try createTable(
            name: modelType.tableName,
            columns: columns,
            foreignKeys: modelType.foreignKeys
        )
    }

    public func save<T: Model>(_ model: T) throws -> T {
        var modelCopy = model
        let dict = model.toDictionary()

        if model.id == nil {
            try insert(into: T.tableName, values: dict)
            let result = try execute("SELECT last_insert_rowid()")
            if let rowId = result.first?["last_insert_rowid()"] as? Int64 {
                modelCopy.id = rowId
            }
        } else {
            let setClause = dict.keys.map { "\($0) = ?" }.joined(separator: ", ")
            var params = Array(dict.values)
            params.append(model.id!)
            _ = try execute(
                "UPDATE \(T.tableName) SET \(setClause) WHERE \(T.primaryKey) = ?",
                parameters: params
            )
        }

        return modelCopy
    }

    public func find<T: Model>(_ id: Int64, modelType: T.Type) throws -> T? {
        let results = try query(
            from: T.tableName,
            where: "\(T.primaryKey) = ?",
            parameters: [id]
        )

        guard let first = results.first else { return nil }
        return try T.fromDictionary(first)
    }

    /// Query all rows of a model type. Use `?` placeholders in `condition` and pass values in `parameters`.
    public func all<T: Model>(_ modelType: T.Type, where condition: String? = nil, parameters: [Any] = []) throws -> [T] {
        let results = try query(from: T.tableName, where: condition, parameters: parameters)
        return try results.map { try T.fromDictionary($0) }
    }

    public func delete<T: Model>(_ model: T) throws {
        guard let id = model.id else {
            throw SwiftLiteDBError.invalidModelDefinition
        }

        _ = try execute(
            "DELETE FROM \(T.tableName) WHERE \(T.primaryKey) = ?",
            parameters: [id]
        )
    }
}
