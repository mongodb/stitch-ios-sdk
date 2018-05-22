import BSON

/**
 * A struct representing a user API key as returned by the Stitch server.
 */
public struct UserAPIKey: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "_id", key, name, disabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try ObjectId.init(fromString: container.decode(String.self, forKey: .id))
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.name = try container.decode(String.self, forKey: .name)
        self.disabled = try container.decode(Bool.self, forKey: .disabled)
    }

    /**
     * The id of the key.
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
