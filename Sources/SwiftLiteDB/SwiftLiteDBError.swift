import Foundation

public enum SwiftLiteDBError: Error {
    case databaseNotInitialized
    case tableAlreadyExists
    case invalidColumnType
    case invalidForeignKey
    case queryError
    case migrationFailed
    case migrationNotFound
    case invalidModelDefinition
    
    public var localizedDescription: String {
        switch self {
        case .databaseNotInitialized:
            return "Database is not initialized"
        case .tableAlreadyExists:
            return "Table already exists"
        case .invalidColumnType:
            return "Invalid column type"
        case .invalidForeignKey:
            return "Invalid foreign key configuration"
        case .queryError:
            return "Error executing query"
        case .migrationFailed:
            return "Migration failed"
        case .migrationNotFound:
            return "Migration not found"
        case .invalidModelDefinition:
            return "Invalid model definition"
        }
    }
}