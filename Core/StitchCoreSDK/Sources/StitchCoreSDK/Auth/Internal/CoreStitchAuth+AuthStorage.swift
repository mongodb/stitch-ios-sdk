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
        do {
            storage.set(try JSONEncoder().encode(StoreAuthInfo.init(withAuthInfo: authInfo)),
                        forKey: activeUserStorageKey)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }
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

        do {
            storage.set(try JSONEncoder().encode(currentUsersStore), forKey: allCurrentUsersStorageKey)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }
    }

    /*
     * Helper function to update the activeUserAuthInfo and activeUser and persist the changes
     */
    internal func updateActiveAuthInfo(withNewAuthInfo authInfo: AuthInfo?) throws {
        let previousUser = activeUser

        // If passed in nil --> clear active auth state
        guard let authInfo = authInfo else {
            activeAuthStateHolder.clearState()

            activeUser = nil
            if let newAuthInfo = activeUserAuthInfo {
                try writeActiveUserAuthInfoToStorage(activeAuthInfo: newAuthInfo)
            }
            dispatchAuthEvent(.activeUserChanged(currentActiveUser: nil,
                                                 previousActiveUser: previousUser))

            return
        }

        // Otherwise make the user
        let user = try makeStitchUser(withAuthInfo: authInfo)

        // Set activeUser, activeUserAuthInfo, and persist
        activeUserAuthInfo = authInfo
        activeUser = user

        // Trigger auth events
        try writeActiveUserAuthInfoToStorage(activeAuthInfo: authInfo)
        dispatchAuthEvent(.activeUserChanged(currentActiveUser: user,
                                             previousActiveUser: previousUser))
    }

    /*
     * Helper function to logout a user with the given id and persist necessary changes
     */
    internal func clearUserAuthToken(forUserID userID: String) throws {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        // Get the user objects if it exists --> otherwise throw
        guard let index = allUsersAuthInfo.firstIndex(where: {$0.userID == userID}) else {
            throw StitchError.clientError(withClientErrorCode: .userNotFound)
        }
        let authInfo = allUsersAuthInfo[index]

        // Remove the auth tokens from the user and persist the list of users
        let newAuthInfo = authInfo.loggedOut
        allUsersAuthInfo[index] = newAuthInfo
        try writeCurrentUsersAuthInfoToStorage()

        // If this is the active user, update the active authInfo and and user
        if userID == activeUserAuthInfo?.userID {
            try updateActiveAuthInfo(withNewAuthInfo: nil)
        }
    }
}
