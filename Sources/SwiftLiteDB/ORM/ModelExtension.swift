import Foundation

extension SwiftLiteDB {
    public func createTable<T: Model>(for modelType: T.Type) throws {
        let columns = modelType.columns.map { key, type in
            if key == modelType.primaryKey {
                return "\(key) \(type)"
            }
            return "\(key) \(type)"
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
            let whereClause = "\(T.primaryKey) = \(model.id!)"
            let setClause = dict.keys.map { "\($0) = ?" }.joined(separator: ", ")
            _ = try execute(
                "UPDATE \(T.tableName) SET \(setClause) WHERE \(whereClause)",
                parameters: Array(dict.values)
            )
        }
        
        return modelCopy
    }
    
    public func find<T: Model>(_ id: Int64, modelType: T.Type) throws -> T? {
        let results = try query(
            from: T.tableName,
            where: "\(T.primaryKey) = \(id)"
        )
        
        guard let first = results.first else {
            return nil
        }
        
        return try T.fromDictionary(first)
    }
    
    public func all<T: Model>(_ modelType: T.Type, where condition: String? = nil) throws -> [T] {
        let results = try query(
            from: T.tableName,
            where: condition
        )
        
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