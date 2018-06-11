import Foundation

/**
 * A protocol representing the fields returned by the Stitch client API in an authentication request.
 */
public protocol APIAuthInfo: Codable {
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
    var accessToken: String { get }

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
 * A protocol representing the combined information represented by `APIAuthInfo` and `ExtendedAuthInfo`
 */
public protocol AuthInfo: APIAuthInfo, ExtendedAuthInfo {
    
}

/**
 * Extension functions for `AuthInfo` which provide mechanisms for reading from and writing to a `Storage`, updating
 * the underlying access token, and merging a new `APIAuthInfo` with an existing `AuthInfo`.
 */
extension AuthInfo {

    /**
     * Reads an `AuthInfo` from some underlying storage.
     *
     * - parameters:
     *     - fromStorage: The `Storage` from which to read the `AuthInfo`.
     * - throws: if the auth information in the underlying storage is corrupted or missing.
     * - returns: An `AuthInfo` containing the stored authentication information.
     */
    public static func read(fromStorage storage: Storage) throws -> AuthInfo? {
        let authInfoAny = storage.value(forKey: "auth_info")

        guard let authData = authInfoAny as? Data else {
            return nil
        }

        return try JSONDecoder().decode(StoreAuthInfo.self, from: authData)
    }

    /**
     * Writes an `AuthInfo` struct into some underlying storage.
     *
     * - parameters:
     *     - toStorage: The `Storage` to which to write the `AuthInfo`.
     * - throws: if the `AuthInfo` could not be encoded into JSON.
     */
    public func write(toStorage storage: inout Storage) throws {
        storage.set(try JSONEncoder().encode(StoreAuthInfo.init(withAuthInfo: self)),
                    forKey: "auth_info")
    }

    /**
     * Clears the authentication information from some underlying storage.
     *
     * - parameters:
     *     - storage: The `Storage` which should be cleared of any authentication information.
     */
    public static func clear(storage: inout Storage) {
        storage.set(nil, forKey: "auth_info")
    }

    /**
     * Merges a new `APIAuthInfo` into some existing `AuthInfo`.
     *
     * - parameters:
     *     - withPartialInfo: The new `APIAuthInfo` to merge with the existing auth info.
     *     - fromOldInfo: The existing `AuthInfo` into which to merge the new `APIAuthInfo`.
     * - returns: The new `AuthInfo` resulting from the merged parameters.
     */
    func merge(withPartialInfo partialInfo: APIAuthInfo, fromOldInfo oldInfo: AuthInfo) -> AuthInfo {
        return StoreAuthInfo.init(withAPIAuthInfo: partialInfo,
                                  withOldInfo: oldInfo)
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
        return StoreAuthInfo.init(withAuthInfo: self, withNewAPIAccessToken: newAccessToken)
    }
}
