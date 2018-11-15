/**
 * A MongoDB namespace, which includes a database name and collection name.
 */
public struct MongoNamespace: Codable, CustomStringConvertible, Hashable {
    private enum CodingKeys: String, CodingKey {
        case databaseName = "db"
        case collectionName = "coll"
    }

    /// the database name
    let databaseName: String
    /// the collection name
    let collectionName: String

    public var description: String {
        return "\(databaseName).\(collectionName)"
    }

    public init(databaseName: String, collectionName: String) {
        self.databaseName = databaseName
        self.collectionName = collectionName
    }
}
