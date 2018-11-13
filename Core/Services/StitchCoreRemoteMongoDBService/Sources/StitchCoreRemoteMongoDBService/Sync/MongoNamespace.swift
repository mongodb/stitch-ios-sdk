/**
 * A MongoDB namespace, which includes a database name and collection name.
 */
public struct MongoNamespace: Codable, CustomStringConvertible, Hashable {
    /// the database name
    let databaseName: String
    /// the collection name
    let collectionName: String

    public var description: String {
        get {
            return "\(databaseName).\(collectionName)"
        }
    }

    public init(databaseName: String, collectionName: String) {
        self.databaseName = databaseName
        self.collectionName = collectionName
    }

    public init(from decoder: Decoder) {
        let description = try! decoder.singleValueContainer().decode(String.self)
        let substrings = description.split(separator: ".")
        self.databaseName = String(substrings[0])
        self.collectionName = String(substrings[1])
    }

    public func encode(to encoder: Encoder) {
        var container = encoder.singleValueContainer()
        try! container.encode(description)
    }
}
