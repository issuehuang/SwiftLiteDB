import Foundation

public struct ForeignKey: Sendable {
    public let column: String
    public let referenceTable: String
    public let referenceColumn: String
    
    public init(column: String, referenceTable: String, referenceColumn: String) {
        self.column = column
        self.referenceTable = referenceTable
        self.referenceColumn = referenceColumn
    }
    
    func sqlString() -> String {
        return "FOREIGN KEY (\(column)) REFERENCES \(referenceTable)(\(referenceColumn))"
    }
}