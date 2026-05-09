import Foundation

/// Schema-modification helpers intended for use inside `Migration.up()` and `Migration.down()`.
/// These methods execute DDL statements where table/column names are schema identifiers
/// and cannot use parameterized bindings — always pass names from code, never from user input.
public extension SwiftLiteDB {

    /// Add a new column to an existing table.
    /// - Parameters:
    ///   - table: Table name.
    ///   - name: New column name.
    ///   - type: SQLite type definition, e.g. `"TEXT"`, `"INTEGER NOT NULL DEFAULT 0"`.
    func addColumn(to table: String, name: String, type: String) throws {
        _ = try execute("ALTER TABLE \(table) ADD COLUMN \(name) \(type)")
    }

    /// Rename a table.
    func renameTable(from oldName: String, to newName: String) throws {
        _ = try execute("ALTER TABLE \(oldName) RENAME TO \(newName)")
    }

    /// Rename a column. Requires SQLite 3.25+ (available on iOS 13+).
    func renameColumn(in table: String, from oldName: String, to newName: String) throws {
        _ = try execute("ALTER TABLE \(table) RENAME COLUMN \(oldName) TO \(newName)")
    }

    /// Drop a column. Requires SQLite 3.35+ (available on iOS 15+).
    func dropColumn(from table: String, name: String) throws {
        _ = try execute("ALTER TABLE \(table) DROP COLUMN \(name)")
    }

    /// Create an index on one or more columns.
    /// - Parameters:
    ///   - name: Index name (must be unique in the database).
    ///   - table: Table to index.
    ///   - columns: One or more column names.
    ///   - unique: Whether to enforce uniqueness.
    func createIndex(name: String, on table: String, columns: [String], unique: Bool = false) throws {
        let uniqueClause = unique ? "UNIQUE " : ""
        let columnList = columns.joined(separator: ", ")
        _ = try execute("CREATE \(uniqueClause)INDEX IF NOT EXISTS \(name) ON \(table) (\(columnList))")
    }

    /// Drop an index by name.
    func dropIndex(name: String) throws {
        _ = try execute("DROP INDEX IF EXISTS \(name)")
    }
}
