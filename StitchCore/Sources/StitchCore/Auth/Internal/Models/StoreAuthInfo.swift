import Foundation

internal struct StoreAuthInfo: Codable, AuthInfo {
    enum CodingKeys: CodingKey {
        case userId, deviceId, accessToken
        case refreshToken, loggedInProviderType, loggedInProviderName
        case userProfile
    }

    let userId: String

    let deviceId: String

    let accessToken: String

    let refreshToken: String

    let loggedInProviderType: String

    let loggedInProviderName: String

    let userProfile: StitchUserProfile

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
     * Initializer for existing auth info but new access token.
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
