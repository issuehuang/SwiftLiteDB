import Foundation

public protocol Migration {
    var version: String { get }
    var name: String { get }
    
    func up(_ db: SwiftLiteDB) throws
    func down(_ db: SwiftLiteDB) throws
}