import Foundation

/**
 * A struct representing a user API key as returned by the Stitch server.
 */
public struct UserAPIKey: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "_id", key, name, disabled
    }
    
    /**
     * The id of the key.
     */
    public let id: String
    
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
