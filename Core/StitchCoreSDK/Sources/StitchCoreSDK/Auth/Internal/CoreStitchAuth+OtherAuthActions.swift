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
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userID else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        guard let index = loggedInUsersAuthInfo.firstIndex(where: {$0.userID == userId}) else {
            throw StitchError.serviceError(
                withMessage: "User with id: \(userId) not found",
                withServiceErrorCode: .userNotFound)
        }
        let authInfo = loggedInUsersAuthInfo[index]

        // If the user is not logged in --> return
        guard authInfo.isLoggedIn else { return }

        // If it is an AnonymousUser remove the user altogether from the list
        // Otherwise set the authInfo to have no access token or refresh token
        var newAuthInfo = StoreAuthInfo.init(withAuthInfo: authInfo, withLogout: true).toAuthInfo
        newAuthInfo = StoreAuthInfo.init(withAuthInfo: newAuthInfo, withNewTime: true).toAuthInfo

        if authInfo.loggedInProviderType == .anonymous {
            loggedInUsersAuthInfo.remove(at: index)
        } else {
            loggedInUsersAuthInfo[index] = newAuthInfo
        }

        try writeCurrentUsersAuthInfoToStorage(
            currentUsersAuthInfo: loggedInUsersAuthInfo,
            toStorage: storage)

        // If this was the active user then set the activeUser to nil and clear its authState
        if userId == activeUserAuthInfo?.userID {
            // This will call onAuthEvent
            clearActiveAuthInfo(storage: storage)
        }

        // Issue the logout request
        _ = try? self.doLogout(authInfo)
    }

    /**
     * Leaves the active user as logged in but makes the user with the given id the active user
     */
    public func switchToUserInternal(withId userId: String) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Get the user objects if it exists --> otherwise throw
        guard let index = loggedInUsersAuthInfo.firstIndex(where: {$0.userID == userId}) else {
            throw StitchError.serviceError(
                withMessage: "User with id: \(userId) not found",
                withServiceErrorCode: .userNotFound)
        }
        let authInfo = loggedInUsersAuthInfo[index]

        if !authInfo.isLoggedIn {
            throw StitchError.serviceError(
                withMessage: "User with id: \(userId) not logged in",
                withServiceErrorCode: .userNotLoggedIn)
        }

        // Trigger Auth Event
        defer { onAuthEvent() }

        // Update the lastAuthActivity of the old and new active user and persist
        if let oldActiveAuthInfo = activeUserAuthInfo {
            if let oldIndex = loggedInUsersAuthInfo.firstIndex(where: {$0.userID == oldActiveAuthInfo.userID}) {
                let oldAuthInfo = StoreAuthInfo.init(withAuthInfo: oldActiveAuthInfo, withNewTime: true).toAuthInfo
                loggedInUsersAuthInfo[oldIndex] = oldAuthInfo
            }
        }
        let newAuthInfo = StoreAuthInfo.init(withAuthInfo: authInfo, withNewTime: true).toAuthInfo
        loggedInUsersAuthInfo[index] = newAuthInfo
        do {
            try writeCurrentUsersAuthInfoToStorage(currentUsersAuthInfo: loggedInUsersAuthInfo, toStorage: storage)
        } catch {
            // Do nothing, would prefer not to fail here 
        }

        // Set the active user and persist
        self.activeUserAuthInfo = authInfo
        let tmpUser = self.userFactory.makeUser(
            withID: authInfo.userID,
            withLoggedInProviderType: authInfo.loggedInProviderType,
            withLoggedInProviderName: authInfo.loggedInProviderName,
            withUserProfile: authInfo.userProfile,
            withIsLoggedIn: authInfo.isLoggedIn,
            withLastAuthActivity: authInfo.lastAuthActivity ?? 0.0)

        self.activeUser = tmpUser
        try writeActiveUserAuthInfoToStorage(activeAuthInfo: authInfo, toStorage: storage)

        return tmpUser
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
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userID else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        guard let index = loggedInUsersAuthInfo.firstIndex(where: {$0.userID == userId}) else {
            throw StitchError.serviceError(
                withMessage: "User with id: \(userId) not found",
                withServiceErrorCode: .userNotFound)
        }
        let authInfo = loggedInUsersAuthInfo[index]

        // remove user from the list of users and persist
        // this will call onAuthEvent() if it is the activeUser
        try clearUser(storage: storage, withUserId: userId)

        // If the user is logged in --> issue a request to logout
        if authInfo.isLoggedIn {
            try doLogout(authInfo)
        }
    }

    /**
     * Returns the list of logged on users or an empty list if nothing is found in storage
     */
    public func listUsersInternal() -> [TStitchUser] {
        var list: [TStitchUser] = []
        for userInfo in self.loggedInUsersAuthInfo {
            list.append(self.userFactory.makeUser(
                withID: userInfo.userID,
                withLoggedInProviderType: userInfo.loggedInProviderType,
                withLoggedInProviderName: userInfo.loggedInProviderName,
                withUserProfile: userInfo.userProfile,
                withIsLoggedIn: userInfo.isLoggedIn,
                withLastAuthActivity: userInfo.lastAuthActivity ?? 0.0))
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

        return try doAuthenticatedRequest(request)
    }
}
