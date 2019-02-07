import Foundation

/**
 * A struct describing the structure of how authentication information is stored in persisted `Storage`.
 */
internal struct StoreAuthInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case userID = "userId", deviceID = "deviceId", accessToken
        case refreshToken, loggedInProviderType, loggedInProviderName
        case userProfile, lastAuthActivity
    }

    /**
     * The id of the Stitch user.
     */
    let userID: String

    /**
     * The device id.
     */
    let deviceID: String?

    /**
     * The temporary access token for the user.
     */
    let accessToken: String?

    /**
     * The permanent (though potentially invalidated) refresh token for the user.
     */
    let refreshToken: String?

    /**
     * A string indicating the type of authentication provider used to log into the current session.
     */
    let loggedInProviderType: StitchProviderType

    /**
     * A string indicating the name of authentication provider used to log into the current session.
     */
    let loggedInProviderName: String

    /**
     * The profile of the currently authenticated user as a `StitchUserProfile`.
     */
    let userProfile: StitchUserProfile

    /**
     * A Double or TimeInterval (alias) representing the time in milliseconds since epoch UTC of the last
     * auth activity for this user on this device
     */
    let lastAuthActivity: Double?

    /**
     * isLoggedIn is a computed property determined by the existance of an accessToken and refreshToken
     */
    var isLoggedIn: Bool {
        return accessToken != nil && refreshToken != nil
    }

    /**
     * Initializes the `StoreAuthInfo` with an `APIAuthInfo` and `ExtendedAuthInfo`.
     */
    init(withAPIAuthInfo newAuthInfo: APIAuthInfo,
         withOldInfo oldAuthInfo: AuthInfo) {
        self.userID = newAuthInfo.userID
        self.deviceID = newAuthInfo.deviceID ?? oldAuthInfo.deviceID
        self.accessToken = newAuthInfo.accessToken
        self.refreshToken = newAuthInfo.refreshToken ?? oldAuthInfo.refreshToken
        self.loggedInProviderType = oldAuthInfo.loggedInProviderType
        self.loggedInProviderName = oldAuthInfo.loggedInProviderName
        self.userProfile = oldAuthInfo.userProfile
        self.lastAuthActivity = oldAuthInfo.lastAuthActivity
    }

    /**
     * Initializes the `StoreAuthInfo` with an `APIAuthInfo` and `ExtendedAuthInfo`.
     */
    init(withAPIAuthInfo newAuthInfo: APIAuthInfo,
         withExtendedAuthInfo extendedAuthInfo: ExtendedAuthInfo) {
        self.userID = newAuthInfo.userID
        self.deviceID = newAuthInfo.deviceID
        self.accessToken = newAuthInfo.accessToken
        self.refreshToken = newAuthInfo.refreshToken
        self.loggedInProviderType = extendedAuthInfo.loggedInProviderType
        self.loggedInProviderName = extendedAuthInfo.loggedInProviderName
        self.userProfile = extendedAuthInfo.userProfile
        self.lastAuthActivity = nil
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
     * Initializes the `StoreAuthInfo` with a plain `AuthInfo` and
     * if withNewTime is true then updates the lastAuthActivity
     */
    init(withAuthInfo authInfo: AuthInfo, withNewTime: Bool? = nil) {
        self.userID = authInfo.userID
        self.deviceID = authInfo.deviceID
        self.accessToken = authInfo.accessToken
        self.refreshToken = authInfo.refreshToken
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile

        if let withNewTime = withNewTime {
            if withNewTime {
                self.lastAuthActivity = Date.init().timeIntervalSince1970
            } else {
                self.lastAuthActivity = authInfo.lastAuthActivity
            }
        } else {
             self.lastAuthActivity = authInfo.lastAuthActivity
        }
    }

    /**
     * Initializes the `StoreAuthInfo` with a plain `AuthInfo` but removes the
     * access token and refresh token if withLogout is true.
     */
    init(withAuthInfo authInfo: AuthInfo, withLogout logout: Bool) {
        self.userID = authInfo.userID
        self.deviceID = authInfo.deviceID
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile

        if logout {
            self.refreshToken = nil
            self.accessToken = nil
            self.lastAuthActivity = Date.init().timeIntervalSince1970
        } else {
            self.accessToken = authInfo.accessToken
            self.refreshToken = authInfo.refreshToken
            self.lastAuthActivity = authInfo.lastAuthActivity
        }
    }

    /**
     * Initializes the `StoreAuthInfo` with a plain `AuthInfo` but changes the provider
     * name and type
     */
    init(withAuthInfo authInfo: AuthInfo,
         withProviderType loggedInProviderType: StitchProviderType,
         withProviderName loggedInProviderName: String) {
        self.userID = authInfo.userID
        self.deviceID = authInfo.deviceID
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.userProfile = authInfo.userProfile
        self.refreshToken = authInfo.refreshToken
        self.accessToken =  authInfo.accessToken
        self.lastAuthActivity = authInfo.lastAuthActivity
    }

    /**
     * Initializes the `StoreAuthInfo`, and an `APIAccessToken` containing a new access token that will
     * overwrite the `AuthInfo`'s acccess token.
     */
    init(withAuthInfo authInfo: AuthInfo, withNewAPIAccessToken newAPIAccessToken: APIAccessToken) {
        self.userID = authInfo.userID
        self.deviceID = authInfo.deviceID
        self.accessToken = newAPIAccessToken.accessToken
        self.refreshToken = authInfo.refreshToken
        self.loggedInProviderType = authInfo.loggedInProviderType
        self.loggedInProviderName = authInfo.loggedInProviderName
        self.userProfile = authInfo.userProfile
        self.lastAuthActivity = authInfo.lastAuthActivity
    }

    /**
     * Memberwise initializer for `StoreAuthInfo`.
     */
    init(userID: String,
         deviceID: String?,
         accessToken: String?,
         refreshToken: String?,
         loggedInProviderType: StitchProviderType,
         loggedInProviderName: String,
         userProfile: StitchUserProfileImpl,
         lastAuthActivity: Double?) {
        self.userID = userID
        self.deviceID = deviceID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.userProfile = userProfile
        self.lastAuthActivity = lastAuthActivity
    }

    /**
     * Initializes the `StoreAuthInfo` from a decoder.
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userID = try container.decode(String.self, forKey: .userID)
        self.deviceID = try container.decode(String.self, forKey: .deviceID)
        self.accessToken = try? container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try? container.decode(String.self, forKey: .refreshToken)
        self.loggedInProviderType = try container.decode(StitchProviderType.self, forKey: .loggedInProviderType)
        self.loggedInProviderName = try container.decode(String.self, forKey: .loggedInProviderName)
        self.userProfile = try container.decode(StoreCoreUserProfile.self, forKey: .userProfile)
        self.lastAuthActivity = try? container.decode(Double.self, forKey: .lastAuthActivity)
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
        try container.encode(StoreCoreUserProfile.init(withUserProfile: self.userProfile),
                             forKey: .userProfile)
        try container.encode(self.lastAuthActivity, forKey: .lastAuthActivity)
    }

    public var toAuthInfo: AuthInfo {
        return AuthInfo.init(userID: userID,
                             deviceID: deviceID,
                             accessToken: accessToken,
                             refreshToken: refreshToken,
                             loggedInProviderType: loggedInProviderType,
                             loggedInProviderName: loggedInProviderName,
                             userProfile: userProfile,
                             lastAuthActivity: lastAuthActivity)
    }
}
