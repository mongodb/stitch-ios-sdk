import Foundation

/**
 * A struct representing the combined information represented by `APIAuthInfo` and `ExtendedAuthInfo`
 */
public struct AuthInfo: Hashable, Equatable {
    public let userID: String?

    public let deviceID: String?

    public let accessToken: String?

    public let refreshToken: String?

    public let loggedInProviderType: StitchProviderType?

    public let loggedInProviderName: String?

    public let userProfile: StitchUserProfile?

    public let lastAuthActivity: TimeInterval?

    /**
     * isLoggedIn is a computed property determined by the existance of an accessToken and refreshToken
     */
    var isLoggedIn: Bool {
        return accessToken != nil && refreshToken != nil
    }

    /**
     * Whether or not this auth info is associated with a user.
     */
    var hasUser: Bool {
        return self.userID != nil
    }

    /**
     * An empty auth info is an auth info associated with no device ID.
     */
    var isEmpty: Bool {
        return self.deviceID == nil
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
    }

    public static func == (lhs: AuthInfo, rhs: AuthInfo) -> Bool {
        return lhs.userID == rhs.userID
    }

    var loggedOut: AuthInfo {
        return AuthInfo.init(
            userID: self.userID,
            deviceID: self.deviceID,
            loggedInProviderType: self.loggedInProviderType,
            loggedInProviderName: self.loggedInProviderName,
            userProfile: self.userProfile,
            lastAuthActivity: Date.init().timeIntervalSince1970)
    }

    var emptiedOut: AuthInfo {
        return AuthInfo.init(deviceID: self.deviceID)
    }

    var withNewAuthActivity: AuthInfo {
        return AuthInfo.init(
            userID: self.userID,
            deviceID: self.deviceID,
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            loggedInProviderType: self.loggedInProviderType,
            loggedInProviderName: self.loggedInProviderName,
            userProfile: self.userProfile,
            lastAuthActivity: Date.init().timeIntervalSince1970)
    }

    public func mergeWithNewAPIAuthInfo(withUserID newUserID: String, withAccessToken newAccessToken: String,
                                        withRefreshToken newRefreshToken: String?,
                                        withDeviceID newDeviceID: String?) -> AuthInfo {
        return AuthInfo.init(
            userID: newUserID,
            deviceID: newDeviceID ?? self.deviceID,
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? self.refreshToken,
            loggedInProviderType: self.loggedInProviderType,
            loggedInProviderName: self.loggedInProviderName,
            userProfile: self.userProfile,
            lastAuthActivity: self.lastAuthActivity
        )
    }

    public func update(withUserID newUserID: String? = nil,
                       withDeviceID newDeviceID: String? = nil,
                       withAccessToken newAccessToken: String? = nil,
                       withRefreshToken newRefreshToken: String? = nil,
                       withLoggedInProviderType newLoggedInProviderType: StitchProviderType? = nil,
                       withLoggedInProviderName newLoggedInProviderName: String? = nil,
                       withUserProfile newUserProfile: StitchUserProfile? = nil,
                       withLastAuthActivity newLastAuthActivity: TimeInterval? = nil) -> AuthInfo {
        return AuthInfo.init(
            userID: newUserID ?? self.userID,
            deviceID: newDeviceID ?? self.deviceID,
            accessToken: newAccessToken ?? self.accessToken,
            refreshToken: newRefreshToken ?? self.refreshToken,
            loggedInProviderType: newLoggedInProviderType ?? self.loggedInProviderType,
            loggedInProviderName: newLoggedInProviderName ?? self.loggedInProviderName,
            userProfile: newUserProfile ?? self.userProfile,
            lastAuthActivity: newLastAuthActivity ?? self.lastAuthActivity
        )
    }

    public func update(withNewAuthInfo authInfo: AuthInfo) -> AuthInfo {
        return AuthInfo.init(
            userID: authInfo.userID ?? self.userID,
            deviceID: authInfo.deviceID ?? self.deviceID,
            accessToken: authInfo.accessToken ?? self.accessToken,
            refreshToken: authInfo.refreshToken ?? self.refreshToken,
            loggedInProviderType: authInfo.loggedInProviderType ?? self.loggedInProviderType,
            loggedInProviderName: authInfo.loggedInProviderName ?? self.loggedInProviderName,
            userProfile: authInfo.userProfile ?? self.userProfile,
            lastAuthActivity: authInfo.lastAuthActivity ?? self.lastAuthActivity)
    }

    /**
     * Initializers
     */
    init(userID: String? = nil, deviceID: String? = nil, accessToken: String? = nil, refreshToken: String? = nil,
         loggedInProviderType: StitchProviderType? = nil, loggedInProviderName: String? = nil,
         userProfile: StitchUserProfile? = nil, lastAuthActivity: TimeInterval? = nil) {
        self.userID = userID
        self.deviceID = deviceID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.userProfile = userProfile
        self.lastAuthActivity = lastAuthActivity
    }
}
