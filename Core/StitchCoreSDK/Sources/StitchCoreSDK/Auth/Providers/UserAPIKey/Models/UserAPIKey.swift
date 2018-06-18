import MongoSwift

/**
 * A struct representing a user API key as returned by the Stitch server.
 */
public struct UserAPIKey: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "_id", key, name, disabled
    }
    
    // MARK: Initializers
    
    /**
     * Initializes the API key from its properties.
     */
    public init(id: ObjectId,
                key: String?,
                name: String,
                disabled: Bool) {
        self.id = id
        self.key = key
        self.name = name
        self.disabled = disabled
    }
    
    /**
     * :nodoc:
     * Initializes the API from a decoder.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try ObjectId.init(fromString: container.decode(String.self, forKey: .id))
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.name = try container.decode(String.self, forKey: .name)
        self.disabled = try container.decode(Bool.self, forKey: .disabled)
    }
    
    // MARK: Properties

    /**
     * The ID of the key.
     */
    public let id: ObjectId

    /**
     * The actual key. Will only be included in the response when an API key is first created.
     */
    public let key: String?

    /**
     * The name of the key.
     */
    public let name: String

    /**
     * Whether or not the key is disabled.
     */
    public let disabled: Bool
}
