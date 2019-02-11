import Foundation

/**
 * A struct describing the structure of how authentication information is stored in persisted `Storage`.
 */
internal struct StoreAuthInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case userID, deviceID, accessToken, refreshToken, loggedInProviderType, loggedInProviderName
        case userProfile, lastAuthActivity
    }

    let userID: String?

    let deviceID: String?

    let accessToken: String?

    let refreshToken: String?

    let loggedInProviderType: StitchProviderType?

    let loggedInProviderName: String?

    let userProfile: StitchUserProfile?

    let lastAuthActivity: TimeInterval?

    var isLoggedIn: Bool {
        return accessToken != nil && refreshToken != nil
    }

    var toAuthInfo: AuthInfo {
        return AuthInfo.init(
            userID: self.userID,
            deviceID: self.deviceID,
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            loggedInProviderType: self.loggedInProviderType,
            loggedInProviderName: self.loggedInProviderName,
            userProfile: self.userProfile,
            lastAuthActivity: self.lastAuthActivity)
    }

    /**
     * Initializes the `StoreAuthInfo` with a plain `AuthInfo`.
     */
    init(withAuthInfo authInfo: AuthInfo) {
        self.userID = authInfo.userID
        self.deviceID = authInfo.deviceID
        self.accessToken = authInfo.accessToken
        self.refreshToken = authInfo.refreshToken
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile
        self.lastAuthActivity = authInfo.lastAuthActivity
    }

    /**
     * Initializes the `AuthInfo` from a decoder.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userID = try? container.decode(String.self, forKey: .userID)
        self.deviceID = try? container.decode(String.self, forKey: .deviceID)
        self.accessToken = try? container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try? container.decode(String.self, forKey: .refreshToken)
        self.loggedInProviderType = try? container.decode(StitchProviderType.self, forKey: .loggedInProviderType)
        self.loggedInProviderName = try? container.decode(String.self, forKey: .loggedInProviderName)
        self.userProfile = try? container.decode(StoreCoreUserProfile.self, forKey: .userProfile)
        self.lastAuthActivity = try? container.decode(TimeInterval.self, forKey: .lastAuthActivity)
    }

    /**
     * Encodes the `StoreAuthInfo` to an encoder.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.userID, forKey: .userID)
        try container.encode(self.deviceID, forKey: .deviceID)
        try container.encode(self.accessToken, forKey: .accessToken)
        try container.encode(self.refreshToken, forKey: .refreshToken)
        try container.encode(self.loggedInProviderType, forKey: .loggedInProviderType)
        try container.encode(self.loggedInProviderName, forKey: .loggedInProviderName)
        if let prof = self.userProfile {
            try container.encode(StoreCoreUserProfile.init(withUserProfile: prof), forKey: .userProfile)
        }
        try container.encode(self.lastAuthActivity, forKey: .lastAuthActivity)
    }
}
