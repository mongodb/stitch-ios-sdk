/**
 * A MongoDB namespace, which includes a database name and collection name.
 */
public struct MongoNamespace: Codable, CustomStringConvertible {
    /// the database name
    let databaseName: String
    /// the collection name
    let collectionName: String

    public lazy var description: String = "\(databaseName).\(collectionName)"
}
