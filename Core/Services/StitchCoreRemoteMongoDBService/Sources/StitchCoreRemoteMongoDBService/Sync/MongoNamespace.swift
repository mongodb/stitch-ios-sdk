/**
 * A MongoDB namespace, which includes a database name and collection name.
 */
public class MongoNamespace: Codable, CustomStringConvertible, Hashable {
    public static func == (lhs: MongoNamespace, rhs: MongoNamespace) -> Bool {
        return lhs.databaseName == rhs.databaseName && lhs.collectionName == rhs.collectionName
    }

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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(databaseName)
        hasher.combine(collectionName)
    }
}
