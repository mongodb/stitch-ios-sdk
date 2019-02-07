import Foundation

/**
 * A protocol representing the fields returned by the Stitch client API in an authentication request.
 */
public protocol APIAuthInfo {
    /**
     * The id of the Stitch user.
     */
    var userID: String { get }

    /**
     * The device id. `nil` in a link request
     */
    var deviceID: String? { get }

    /**
     * The temporary access token for the user.
     */
    var accessToken: String? { get }

    /**
     * The permanent (though potentially invalidated) refresh token for the user. `nil` in a link request
     */
    var refreshToken: String? { get }
}

/**
 * A protocol representing authenticaftion information not returned immediately by the Stitch client API in an
 * authentication request.
 */
public protocol ExtendedAuthInfo {
    /**
     * The type of authentication provider used to log into the current session.
     */
    var loggedInProviderType: StitchProviderType { get }

    /**
     * A string indicating the name of authentication provider used to log into the current session.
     */
    var loggedInProviderName: String { get }

    /**
     * The profile of the currently authenticated user as a `StitchUserProfile`.
     */
    var userProfile: StitchUserProfile { get }
}

/**
 * A protocol representing device related auth information
 */
public protocol DeviceAuthInfo {
    var deviceID: String? { get }
}

/**
 * A struct representing the combined information represented by `APIAuthInfo` and `ExtendedAuthInfo`
 */
public struct AuthInfo: APIAuthInfo, ExtendedAuthInfo, DeviceAuthInfo, Hashable {
    public static func == (lhs: AuthInfo, rhs: AuthInfo) -> Bool {
        return lhs.userID == rhs.userID
    }

    public var userID: String

    public var deviceID: String?

    public var accessToken: String?

    public var refreshToken: String?

    public var loggedInProviderType: StitchProviderType

    public var loggedInProviderName: String

    public var userProfile: StitchUserProfile

    public var lastAuthActivity: Double?

    /**
     * isLoggedIn is a computed property determined by the existance of an accessToken and refreshToken
     */
    var isLoggedIn: Bool {
        return accessToken != nil && refreshToken != nil
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
    }
}

/**
 * Extension functions for `AuthInfo` which provide mechanisms for reading from and writing to a `Storage`, updating
 * the underlying access token, and merging a new `APIAuthInfo` with an existing `AuthInfo`.
 */
extension AuthInfo {
    /**
     * Merges a new `APIAuthInfo` into some existing `AuthInfo`.
     *
     * - parameters:
     *     - withPartialInfo: The new `APIAuthInfo` to merge with the existing auth info.
     *     - fromOldInfo: The existing `AuthInfo` into which to merge the new `APIAuthInfo`.
     * - returns: The new `AuthInfo` resulting from the merged parameters.
     */
    func merge(withPartialInfo partialInfo: APIAuthInfo, fromOldInfo oldInfo: AuthInfo) -> AuthInfo {
        return StoreAuthInfo.init(withAPIAuthInfo: partialInfo, withOldInfo: oldInfo).toAuthInfo
    }

    /**
     * Returns a new `AuthInfo` representing the current `AuthInfo` but with a new access token.
     *
     * - important: This is not a mutating function. Only the return value will have the new access token.
     * - parameters:
     *     - withNewAccessToken: The `APIAccessToken` representing the new access token to put into this `AuthInfo`.
     * - returns: The `AuthInfo` that results from updating the access token.
     */
    func refresh(withNewAccessToken newAccessToken: APIAccessToken) -> AuthInfo {
        return StoreAuthInfo.init(withAuthInfo: self, withNewAPIAccessToken: newAccessToken).toAuthInfo
    }
}
