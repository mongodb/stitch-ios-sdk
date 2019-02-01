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
     * - parameters:
     *     - fromStorage: The `Storage` from which to read the `AuthInfo`.
     * - throws: if the auth information in the underlying storage is corrupted or missing.
     * - returns: An `AuthInfo` containing the stored authentication information.
     */
    internal func readActiveUserAuthInfoFromStorage(fromStorage storage: Storage) throws -> AuthInfo? {
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
     *     - toStorage: The `Storage` to which to write the `AuthInfo`.
     * - throws: if the `AuthInfo` could not be encoded into JSON.
     */
    internal func writeActiveUserAuthInfoToStorage(activeAuthInfo authInfo: AuthInfo,
                                                   toStorage storage: Storage) throws {
        storage.set(try JSONEncoder().encode(StoreAuthInfo.init(withAuthInfo: authInfo)),
                    forKey: activeUserStorageKey)
    }

    /**
     * Reads an Array of `AuthInfo` from some underlying storage.
     *
     * - parameters:
     *     - fromStorage: The `Storage` from which to read the `AuthInfo` array.
     * - throws: if the auth information in the underlying storage is corrupted or missing.
     * - returns: A List of [`AuthInfo`] classes.
     */
    internal func readCurrentUsersAuthInfoFromStorage(fromStorage storage: Storage) throws -> [AuthInfo] {
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
     * - parameters:
     *     - currentUsersAuthInfo: An array of `AuthInfo` structs to write to `Storage`
     *     - toStorage: The `Storage` to which to write the `AuthInfo`.
     * - throws: if the `AuthInfo` could not be encoded into JSON.
     */
    internal func writeCurrentUsersAuthInfoToStorage(currentUsersAuthInfo currentUsers: [AuthInfo],
                                                     toStorage storage: Storage) throws {
        var currentUsersStore: [StoreAuthInfo] = []
        for user in currentUsers {
            currentUsersStore.append(StoreAuthInfo.init(withAuthInfo: user))
        }

        storage.set(try JSONEncoder().encode(currentUsersStore), forKey: allCurrentUsersStorageKey)
    }

    /**
     * Clears the authentication information for the user with the given id.
     *
     * - parameters:
     *     - storage: The `Storage` which should be cleared of any authentication information.
     */
    internal func clearUser(storage: Storage, withUserId userId: String?) throws {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        // Unwrap the userId and set it to the given id or that of the active user
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userID else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        let (index, _) = try getUserAndIndexOrThrow(withId: userId)

        // Otherwise remove the user and persist the list
        loggedInUsersAuthInfo.remove(at: index)
        try writeCurrentUsersAuthInfoToStorage(
            currentUsersAuthInfo: loggedInUsersAuthInfo,
            toStorage: storage)

        // If it was the active user --> remove
        if userId == activeUserAuthInfo?.userID {
            clearActiveUser(storage: storage)
        }

        // TODO Delete mobile SYNC data
    }

    internal func clearActiveUser(storage: Storage) {
        storage.set(nil, forKey: activeUserStorageKey)
        self.authStateHolder.clearState()
        self.activeUser = nil
        onAuthEvent()

    }

    /**
     * Clears the authentication information for the currently active user.
     *
     * - parameters:
     *     - storage: The `Storage` which should be cleared of any authentication information.
     */

    /**
     * Clears the `CoreStitchAuth`'s entire authentication state, as well as associated authentication
     * state in underlying storage.
     */
    internal func clearAllAuth() {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        // Do we want this?
//        guard self.isLoggedIn else { return }

        self.authStateHolder.clearState()
        self.activeUser = nil
        storage.set(nil, forKey: allCurrentUsersStorageKey)
        storage.set(nil, forKey: activeUserStorageKey)
    }
}
