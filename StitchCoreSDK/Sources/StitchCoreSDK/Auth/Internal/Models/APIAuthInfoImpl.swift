import Foundation

/**
 * A struct containing the fields returned by the Stitch client API in an authentication request.
 */
public struct APIAuthInfoImpl: APIAuthInfo {
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
    public let accessToken: String

    /**
     * The permanent (though potentially invalidated) access token for the newly authenticated user. This will be `nil`
     * in a link request.
     */
    public let refreshToken: String?
}

/**
 * A struct containing the extended authentication information required by the `ExtendedAuthInfo` protocol.
 */
public struct ExtendedAuthInfoImpl: ExtendedAuthInfo {
    /**
     * The type of authentication provider used to log in as this user.
     */
    public let loggedInProviderType: StitchProviderType

    /**
     * The name of the authentication provider used to log in as this user.
     */
    public let loggedInProviderName: String

    /**
     * A `StitchUserProfile` object describing this user.
     */
    public let userProfile: StitchUserProfile
}
