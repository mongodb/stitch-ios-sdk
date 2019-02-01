import Foundation
import MongoSwift

extension CoreStitchAuth {
    /**
     * Logs out the current user, and clears authentication state from this `CoreStitchAuth` as well as underlying
     * storage. Blocks the current thread until the request is completed. If the logout request fails, this method will
     * still clear local authentication state.
     */
    public func logoutInternal(withUserId userId: String?) throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Unwrap the userId or use the active user
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userID else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        let (index, authInfo) = try getUserAndIndexOrThrow(withId: userId)

        // If the user is not logged in --> return
        guard authInfo.isLoggedIn else { return }

        // If it is an AnonymousUser remove the user altogether from the list
        // Otherwise set the authInfo to have no access token or refresh token
        let newAuthInfo = StoreAuthInfo.init(withAuthInfo: authInfo, withLogout: true).toAuthInfo
        if authInfo.loggedInProviderType == .anonymous {
            loggedInUsersAuthInfo.remove(at: index)
        } else {
            loggedInUsersAuthInfo[index] = newAuthInfo
        }

        // TODO: what should happen if we fail here?
        try writeCurrentUsersAuthInfoToStorage(
            currentUsersAuthInfo: loggedInUsersAuthInfo,
            toStorage: storage)

        // If this was the active user then set the activeUser to nil and clear its authState
        if userId == activeUserAuthInfo?.userID {
            // This will call onAuthEvent
            clearActiveUser(storage: storage)
        }

        // Issue the logout request
        _ = try? self.doLogout(authInfo)
    }

    /**
     * Leaves the active user as logged in but makes the user with the given id the active user
     */
    public func switchToUserWithIdInternal(_ userId: String) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Get the user objects if it exists --> otherwise throw
        let (index, authInfo) = try getUserAndIndexOrThrow(withId: userId)

        if !authInfo.isLoggedIn {
            throw StitchError.serviceError(
                withMessage: "User with id: \(userId) not logged in",
                withServiceErrorCode: .userNotLoggedIn)
        }

        // TK-TODO - Must add the new modified time --> will need to update the list

        // Trigger Auth Event
        defer { onAuthEvent() }

        // Set the active user and persist
        self.activeUserAuthInfo = authInfo
        let tmpUser = self.userFactory.makeUser(
            withID: authInfo.userID,
            withLoggedInProviderType: authInfo.loggedInProviderType,
            withLoggedInProviderName: authInfo.loggedInProviderName,
            withUserProfile: authInfo.userProfile,
            withIsLoggedIn: authInfo.isLoggedIn)
        self.activeUser = tmpUser
        try writeActiveUserAuthInfoToStorage(activeAuthInfo: authInfo, toStorage: storage)

        return tmpUser
    }

    /**
     * Logs out and removes the a user with the provided id.
     * Throws an exception if the user was not found.
     * If no userId is given, then it removes the active user
     */
    public func removeUserInternal(withUserId userId: String?) throws {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Unwrap the userId or use the active user
        guard let userId = userId != nil ? userId : activeUserAuthInfo?.userID else {
            return
        }

        // Get the user objects if it exists --> otherwise throw
        let (_, authInfo) = try getUserAndIndexOrThrow(withId: userId)

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
                withIsLoggedIn: userInfo.isLoggedIn))
        }

        // list.sort(by: {
        //    ($0.firstName, -$0.lastName) < ($1.firstName, -$1.lastName)
        // })
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
