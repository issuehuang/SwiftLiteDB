import Foundation

public protocol Model: Codable, Sendable {
    static var tableName: String { get }
    static var primaryKey: String { get }
    static var columns: [String: String] { get }
    static var foreignKeys: [ForeignKey]? { get }
    
    var id: Int64? { get set }
}

// Default implementations
public extension Model {
    static var primaryKey: String {
        return "id"
    }
    
    static var foreignKeys: [ForeignKey]? {
        return nil
    }
    
    func toDictionary() -> [String: Any] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: Any] = [:]

        for child in mirror.children {
            if let label = child.label {
                if label != "id" || self.id != nil {
                    dict[label] = Self.encodeValue(child.value)
                }
            }
        }

        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) throws -> Self {
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: jsonData)
    }

    /// Converts a value to a SQLite-storable type.
    /// Handles Optional unwrapping, Date → ISO8601 String, UUID → String.
    private static func encodeValue(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let unwrapped = mirror.children.first?.value else { return NSNull() }
            return encodeValue(unwrapped)
        }
        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }
        if let uuid = value as? UUID {
            return uuid.uuidString
        }
        return value
    }
}