import Foundation

/**
 * A struct representing the response received from the Stitch server for a session request made to refresh an access
 * token.
 */
internal struct APIAccessToken: Decodable {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }

    /**
     * The new access token in the response.
     */
    public let accessToken: String
}
