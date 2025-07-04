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
                // 只有在 id 不為 nil 或者不是 id 欄位時才加入
                if label != "id" || self.id != nil {
                    dict[label] = child.value
                }
            }
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> Self {
        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: jsonData)
    }
}