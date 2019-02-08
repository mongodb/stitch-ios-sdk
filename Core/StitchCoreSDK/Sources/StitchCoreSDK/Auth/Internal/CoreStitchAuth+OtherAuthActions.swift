import Foundation
import MongoSwift

extension CoreStitchAuth {
    /**
     * Logs out the current user, and clears authentication state from this `CoreStitchAuth` as well as underlying
     * storage. Blocks the current thread until the request is completed. If the logout request fails, this method will
     * still clear local authentication state.
     */
    public func logoutInternal(withId userId: String?) throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Unwrap the userId or use the active user
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userId else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        guard let index = allUsersAuthInfo.firstIndex(where: {$0.userId == userId}) else {
            throw StitchError.clientError(withClientErrorCode: .userNotFound)
        }
        let authInfo = allUsersAuthInfo[index]

        // If the user is not logged in --> return
        guard allUsersAuthInfo[index].isLoggedIn else { return }

        // If this is an anonymous user --> remove it (will perform logout)
        if authInfo.loggedInProviderType == .anonymous {
            return try removeUserInternal(withId: userId)
        }

        // Issue the logout request
        _ = try? self.doLogout(authInfo)

        // Update the AuthInfo to remove the tokens and update the lastAuthActivity
        try clearUserAuthToken(forUserId: userId)
    }

    /**
     * Leaves the active user as logged in but makes the user with the given id the active user
     */
    public func switchToUserInternal(withId userId: String) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Get the user objects if it exists --> otherwise throw
        guard let index = allUsersAuthInfo.firstIndex(where: {$0.userId == userId}) else {
            throw StitchError.clientError(withClientErrorCode: .userNotFound)
        }
        let authInfo = allUsersAuthInfo[index]

        // If the user is not logged in, throw a userNoLongerValid ClientError
        if !authInfo.isLoggedIn {
            throw StitchError.clientError(withClientErrorCode: .userNoLongerValid)
        }

        // Update the lastAuthActivity of the old and new active user and persist
        if let oldActiveAuthInfo = activeUserAuthInfo {
            if let oldIndex = allUsersAuthInfo.firstIndex(where: {$0.userId == oldActiveAuthInfo.userId}) {
                allUsersAuthInfo[oldIndex] = oldActiveAuthInfo.withNewAuthActivity
            }
        }

        // Update the time of the new auth info
        let newAuthInfo = authInfo.withNewAuthActivity
        allUsersAuthInfo[index] = newAuthInfo

        // Persist the list of users
        try writeCurrentUsersAuthInfoToStorage()

        // Update the active user
        try updateActiveAuthInfo(withNewAuthInfo: newAuthInfo)

        // This should never happen because it is set right above in updateActiveAuthInfo
        // but throw an error if there is no activeUser
        guard let user = activeUser else {
            throw StitchError.clientError(withClientErrorCode: .couldNotFindActiveUser)
        }

        // Trigger auth events
        onAuthEvent()

        return user
    }

    /**
     * Logs out and removes the a user with the provided id.
     * Throws an exception if the user was not found.
     * If no userId is given, then it removes the active user
     */
    public func removeUserInternal(withId userId: String?) throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Unwrap the userId or use the active user
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userId else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        guard let index = allUsersAuthInfo.firstIndex(where: {$0.userId == userId}) else {
            throw StitchError.clientError(withClientErrorCode: .userNotFound)
        }
        let authInfo = allUsersAuthInfo[index]

        // If the user is logged in --> logout
        if authInfo.isLoggedIn {
            _ = try? doLogout(authInfo)
        }

        // Remove the user from allUsersAuthInfo and persist
        allUsersAuthInfo.remove(at: index)
        try writeCurrentUsersAuthInfoToStorage()

        // If this is the active user --> remove
        if userId == activeUserAuthInfo?.userId {
            try updateActiveAuthInfo(withNewAuthInfo: nil)
        }
    }

    /**
     * Returns the list of logged on users or an empty list if nothing is found in storage
     */
    public func listUsersInternal() -> [TStitchUser] {
        var list: [TStitchUser] = []
        for userInfo in self.allUsersAuthInfo {
            if let newUser = makeStitchUser(withAuthInfo: userInfo) {
                list.append(newUser)
            }
        }

        return list
    }

    /**
     * Performs a logout request against the Stitch server.
     */
    @discardableResult
    internal func doLogout(_ userInfo: AuthInfo) throws -> Response {
        var request = try StitchAuthRequestBuilder()
            .withRefreshToken()
            .with(path: authRoutes.sessionRoute)
            .with(method: .delete)
            .build()

        request = try StitchAuthRequest.init(
            stitchRequest: prepareAuthRequest(withAuthRequest: request, withAuthInfo: userInfo),
            useRefreshToken: false)

        onAuthEvent()
        return try doAuthenticatedRequest(request)
    }
}
