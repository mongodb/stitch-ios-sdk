import Foundation

/**
 * A struct describing the structure of how authentication information is stored in persisted `Storage`.
 */
internal struct StoreAuthInfo: Codable, AuthInfo {
    enum CodingKeys: CodingKey {
        case userId, deviceId, accessToken
        case refreshToken, loggedInProviderType, loggedInProviderName
        case userProfile
    }

    /**
     * The ID of the Stitch user.
     */
    let userId: String

    /**
     * The device ID.
     */
    let deviceId: String

    /**
     * The temporary access token for the user.
     */
    let accessToken: String

    /**
     * The permanent refresh token for the user.
     */
    let refreshToken: String

    /**
     * A string indicating the type of authentication provider used to log into the current session.
     */
    let loggedInProviderType: String

    /**
     * A string indicating the name of authentication provider used to log into the current session.
     */
    let loggedInProviderName: String

    /**
     * The profile of the currently authenticated user as a `StitchUserProfile`.
     */
    let userProfile: StitchUserProfile

    /**
     * Initializes the `StoreAuthInfo` with an `APIAuthInfo` and `ExtendedAuthInfo`.
     */
    init(withAPIAuthInfo apiAuthInfo: APIAuthInfo,
         withExtendedAuthInfo extendedAuthInfo: ExtendedAuthInfo) {
        self.userId = apiAuthInfo.userId
        self.deviceId = apiAuthInfo.deviceId
        self.accessToken = apiAuthInfo.accessToken
        self.refreshToken = apiAuthInfo.refreshToken
        self.loggedInProviderType = extendedAuthInfo.loggedInProviderType
        self.loggedInProviderName = extendedAuthInfo.loggedInProviderName
        self.userProfile = extendedAuthInfo.userProfile
    }

    /**
     * Initializes the `StoreAuthInfo` with a plain `AuthInfo`.
     */
    init(withAuthInfo authInfo: AuthInfo) {
        self.userId = authInfo.userId
        self.deviceId = authInfo.deviceId
        self.accessToken = authInfo.accessToken
        self.refreshToken = authInfo.refreshToken
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile
    }

    /**
     * Initializes the `StoreAuthInfo`, and an `APIAccessToken` containing a new access token that will
     * overwrite the `AuthInfo`'s acccess token.
     */
    init(withAuthInfo authInfo: AuthInfo, withNewAPIAccessToken newAPIAccessToken: APIAccessToken) {
        self.userId = authInfo.userId
        self.deviceId = authInfo.deviceId
        self.accessToken = newAPIAccessToken.accessToken
        self.refreshToken = authInfo.refreshToken
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile
    }

    /**
     * Initializes the `StoreAuthInfo` from a decoder.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.userId = try container.decode(String.self, forKey: .userId)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.loggedInProviderType = try container.decode(String.self, forKey: .loggedInProviderType)
        self.loggedInProviderName = try container.decode(String.self, forKey: .loggedInProviderName)
        self.userProfile = try container.decode(StoreCoreUserProfile.self, forKey: .userProfile)
    }

    /**
     * Encodes the `StoreAuthInfo` to an encoder.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.userId, forKey: .userId)
        try container.encode(self.deviceId, forKey: .deviceId)
        try container.encode(self.accessToken, forKey: .accessToken)
        try container.encode(self.refreshToken, forKey: .refreshToken)
        try container.encode(self.loggedInProviderType, forKey: .loggedInProviderType)
        try container.encode(self.loggedInProviderName, forKey: .loggedInProviderName)
        try container.encode(StoreCoreUserProfile.init(withUserProfile: self.userProfile),
                             forKey: .userProfile)
    }
}
