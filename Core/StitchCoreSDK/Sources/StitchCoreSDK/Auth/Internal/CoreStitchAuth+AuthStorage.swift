import Foundation
import MongoSwift

private let activeUserStorageKey = "auth_info"
private let allCurrentUsersStorageKey = "all_users"

/**
 * Extension functions for `CoreStitchAuth` persist Auth Information
 */
extension CoreStitchAuth {
    /**
     * Reads an `AuthInfo` from some underlying storage.
     *
     * - throws: if the auth information in the underlying storage is corrupted or missing.
     * - returns: An `AuthInfo` containing the stored authentication information.
     */
    internal func readActiveUserAuthInfoFromStorage() throws -> AuthInfo? {
        let authInfoAny = storage.value(forKey: activeUserStorageKey)

        guard let authData = authInfoAny as? Data else {
            return nil
        }
        return try JSONDecoder().decode(StoreAuthInfo.self, from: authData).toAuthInfo
    }

    /**
     * Writes an `AuthInfo` struct into some underlying storage.
     *
     * - parameters:
     *     - activeAuthInfo: The `AuthInfo` to write to `Storage`
     * - throws: if the `AuthInfo` could not be encoded into JSON.
     */
    internal func writeActiveUserAuthInfoToStorage(activeAuthInfo authInfo: AuthInfo) throws {
        storage.set(try JSONEncoder().encode(StoreAuthInfo.init(withAuthInfo: authInfo)),
                    forKey: activeUserStorageKey)
    }

    /**
     * Reads an Array of `AuthInfo` from some underlying storage.
     *
     * - throws: if the auth information in the underlying storage is corrupted or missing.
     * - returns: A List of [`AuthInfo`] classes.
     */
    internal func readCurrentUsersAuthInfoFromStorage() throws -> [AuthInfo] {
        var authInfos: [AuthInfo] = []
        let authInfoAny = storage.value(forKey: allCurrentUsersStorageKey)

        guard let authData = authInfoAny as? Data else {
            return authInfos
        }

        let storeAuthInfos = try JSONDecoder().decode([StoreAuthInfo].self, from: authData)
        for storeAuthInfo in storeAuthInfos {
            authInfos.append(storeAuthInfo.toAuthInfo)
        }
        return authInfos
    }

    /**
     * Writes a list of `AuthInfo` structs into some underlying storage.
     *
     * - throws: if the `AuthInfo` could not be encoded into JSON.
     */
    internal func writeCurrentUsersAuthInfoToStorage() throws {
        var currentUsersStore: [StoreAuthInfo] = []
        for user in allUsersAuthInfo {
            currentUsersStore.append(StoreAuthInfo.init(withAuthInfo: user))
        }

        storage.set(try JSONEncoder().encode(currentUsersStore), forKey: allCurrentUsersStorageKey)
    }

    /*
     * Helper function to update the activeUserAuthInfo and activeUser and persist the changes
     */
    internal func updateActiveAuthInfo(withNewAuthInfo authInfo: AuthInfo?) throws {
        guard let authInfo = authInfo else {
            // TODO
            authStateHolder.clearState()
            activeUser = nil
            storage.set(activeUserAuthInfo, forKey: activeUserStorageKey)
            return
        }

        activeUserAuthInfo = authInfo
        activeUser = userFactory.makeUser(
            withID: authInfo.userID,
            withLoggedInProviderType: authInfo.loggedInProviderType,
            withLoggedInProviderName: authInfo.loggedInProviderName,
            withUserProfile: authInfo.userProfile,
            withIsLoggedIn: authInfo.isLoggedIn,
            withLastAuthActivity: authInfo.lastAuthActivity ?? Date.init().timeIntervalSince1970)
        try writeActiveUserAuthInfoToStorage(activeAuthInfo: authInfo)
    }

    /*
     * Helper function to logout a user with the given id and persist necessary changes
     */
    internal func clearUserAuthToken(forUserId userId: String) throws {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        // Get the user objects if it exists --> otherwise throw
        guard let index = allUsersAuthInfo.firstIndex(where: {$0.userID == userId}) else {
            throw StitchError.clientError(withClientErrorCode: .userNotFound)
        }
        let authInfo = allUsersAuthInfo[index]

        // Otherwise, update the AuthInfo to remove the tokens and update the lastAuthActivity
        let newAuthInfo = StoreAuthInfo.init(
            withAuthInfo: authInfo,
            withOptions: [.updateLastAuthActivity, .removeAuthTokens]).toAuthInfo
        allUsersAuthInfo[index] = newAuthInfo
        try writeCurrentUsersAuthInfoToStorage()

        // If this is the active user, update the active authInfo and and user
        if userId == activeUserAuthInfo?.userID {
            try updateActiveAuthInfo(withNewAuthInfo: nil)
        }
    }
}
