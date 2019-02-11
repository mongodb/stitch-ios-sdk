import Foundation

/**
 * A struct containing the fields returned by the Stitch client API in an authentication request.
 */
public struct APIAuthInfoImpl: Codable {
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case deviceID = "device_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    /**
     * The id of the newly authenticated user.
     */
    public let userID: String

    /**
     * The device id of the newly authenticated user. This will be `nil` in a link request.
     */
    public let deviceID: String?

    /**
     * The temporary access token for the newly authenticated user.
     */
    public let accessToken: String?

    /**
     * The permanent (though potentially invalidated) access token for the newly authenticated user. This will be `nil`
     * in a link request.
     */
    public let refreshToken: String?
}
