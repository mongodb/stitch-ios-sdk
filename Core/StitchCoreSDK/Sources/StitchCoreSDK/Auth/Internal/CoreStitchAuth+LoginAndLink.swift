import Foundation
import MongoSwift

/**
 * Extension functions for `CoreStitchAuth` to perform login
 */
extension CoreStitchAuth {
    /**
     * Authenticates the `CoreStitchAuth` using the provided `StitchCredential. Blocks the current thread until the
     * request is completed.
     */
    public func loginWithCredentialInternal(withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Iterate over all logged in user to see if we can re-login
        if credential.providerCapabilities.reusesExistingSession {
            for user in loggedInUsersAuthInfo {
                if type(of: credential).providerType == user.loggedInProviderType {
                    // Switch to this user --> it will persist auth changes
                    return try switchToUserWithIdInternal(user.userID)
                }
            }
        }

        // Otherwise, doLogin() will change the auth data structures and persist them
        return try doLogin(withCredential: credential, asLinkRequest: false)
    }
    
    /**
     * Links the currently logged in user with a new identity represented by the provided `StitchCredential. Blocks the
     * current thread until the request is completed.
     */
    public func linkUserWithCredentialInternal(withUser user: TStitchUser,
                                               withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }
        guard let activeUser = self.activeUser,
            user == activeUser else {
                throw StitchError.clientError(withClientErrorCode: .userNoLongerValid)
        }
        
        return try self.doLogin(withCredential: credential, asLinkRequest: true)
    }

    /**
     * Performs the logic of logging in this `CoreStitchAuth` as a new user with the provided credential. Can also
     * perform a user link if the `asLinkRequest` parameter is true.
     *
     * - important: Callers of `doLogin` should be synchronized before calling in.
     */
    internal func doLogin(withCredential credential: StitchCredential, asLinkRequest: Bool) throws -> TStitchUser {
        let response = try self.doLoginRequest(withCredential: credential, asLinkRequest: asLinkRequest)
        let user = try self.processLoginResponse(withCredential: credential,
                                                 forResponse: response,
                                                 asLinkRequest: asLinkRequest)
        onAuthEvent()
        return user
    }

    /**
     * Performs the login request against the Stitch server. If `asLinkRequest` is true, a link request is performed
     * instead.
     */
    internal func doLoginRequest(withCredential credential: StitchCredential,
                                 asLinkRequest: Bool) throws -> Response {
        let reqBuilder = StitchDocRequestBuilder()

        reqBuilder.with(method: .post)

        if asLinkRequest {
            reqBuilder.with(path: authRoutes.authProviderLinkRoute(withProviderName: credential.providerName))
        } else {
            reqBuilder.with(path: authRoutes.authProviderLoginRoute(withProviderName: credential.providerName))
        }

        var body = credential.material
        self.attachAuthOptions(authBody: &body)
        reqBuilder.with(document: body)

        if !asLinkRequest {
            return try self.requestClient.doRequest(reqBuilder.build())
        }
        return try doAuthenticatedRequest(
            StitchAuthDocRequest.init(stitchRequest: reqBuilder.build(), document: body)
        )
    }

    /**
     * Processes the response of the login/link request, setting the authentication state if appropriate, and
     * requesting the user profile in a separate request.
     */
    internal func processLoginResponse(withCredential credential: StitchCredential,
                                       forResponse response: Response,
                                       asLinkRequest: Bool) throws -> TStitchUser {
        guard let body = response.body else {
            throw StitchError.serviceError(
                withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                withServiceErrorCode: .unknown
            )
        }

        var decodedInfo: APIAuthInfoImpl!
        do {
            decodedInfo = try JSONDecoder().decode(APIAuthInfoImpl.self, from: body)
        } catch {
            throw StitchError.requestError(withError: error, withRequestErrorCode: .decodingError)
        }

        // Preserve old auth info in case of profile request failure
        let oldAuthInfo = self.activeUserAuthInfo
        let oldUser = self.activeUser

        // Provisionally set auth info so we can make a profile request
        var newAPIAuthInfo: APIAuthInfo!
        if let oldAuthInfo = oldAuthInfo {
            let newAuthInfo = oldAuthInfo.merge(withPartialInfo: decodedInfo, fromOldInfo: oldAuthInfo)
            newAPIAuthInfo = newAuthInfo
            activeUserAuthInfo = newAuthInfo
        } else {
            newAPIAuthInfo = decodedInfo
            authStateHolder.apiAuthInfo = decodedInfo
        }

        // Get User Profile
        var profile: StitchUserProfile!
        do {
            profile = try doGetUserProfile()
        } catch let err {
            // If this was a link request or another user is logged in, back out of setting authInfo
            // and reset any created user. This will keep the currently logged in user logged in if
            // the profile request failed, and in this particular edge case the user is linked,
            // but they are logged in with their older credentials.
            if asLinkRequest {
                self.activeUserAuthInfo = nil
                self.activeUser = nil

                if let authInfo = oldAuthInfo {
                    self.activeUserAuthInfo = StoreAuthInfo.init(
                        withAuthInfo: authInfo,
                        withProviderType: type(of: credential).providerType,
                        withProviderName: credential.providerName).toAuthInfo

                    self.activeUser = self.userFactory.makeUser(
                        withID: authInfo.userID,
                        withLoggedInProviderType: type(of: credential).providerType,
                        withLoggedInProviderName: credential.providerName,
                        withUserProfile: authInfo.userProfile,
                        withIsLoggedIn: authInfo.isLoggedIn)
                }
            } else if !self.loggedInUsersAuthInfo.isEmpty {
                self.activeUserAuthInfo = oldAuthInfo
                self.activeUser = oldUser
            } else {
                clearAllAuth()
            }

            throw err
        }

        // Finally set the info and user
        let newAuthInfo = StoreAuthInfo.init(
            withAPIAuthInfo: newAPIAuthInfo,
            withExtendedAuthInfo: ExtendedAuthInfoImpl.init(loggedInProviderType: type(of: credential).providerType,
                                                            loggedInProviderName: credential.providerName,
                                                            userProfile: profile)).toAuthInfo

        let newUser = self.userFactory.makeUser(withID: newAuthInfo.userID,
                                                withLoggedInProviderType: newAuthInfo.loggedInProviderType,
                                                withLoggedInProviderName: newAuthInfo.loggedInProviderName,
                                                withUserProfile: newAuthInfo.userProfile,
                                                withIsLoggedIn: newAuthInfo.isLoggedIn)

        // Persist auth info to storage, and return the resulting StitchUser
        do {
            try writeActiveUserAuthInfoToStorage(activeAuthInfo: newAuthInfo, toStorage: storage)
        } catch {
            // Back out of setting authInfo
            self.activeUserAuthInfo = oldAuthInfo
            self.activeUser = oldUser

            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }

        // If the user already exists update it, otherwise append it to the list
        var index: Int = -1
        var oldAuthInfoForNewUser: AuthInfo?

        do {
            let (oldIndex, oldInfo) = try getUserAndIndexOrThrow(withId: newAuthInfo.userID)
            index = oldIndex
            oldAuthInfoForNewUser = oldInfo
            loggedInUsersAuthInfo[index] = newAuthInfo
        } catch {
            index = loggedInUsersAuthInfo.count
            loggedInUsersAuthInfo.append(newAuthInfo)
        }

        // Persist the changes
        do {
            try writeCurrentUsersAuthInfoToStorage(
                currentUsersAuthInfo: loggedInUsersAuthInfo,
                toStorage: storage)
        } catch {
            // Back out of setting auth info
            self.activeUserAuthInfo = oldAuthInfo
            self.activeUser = oldUser

            if let oldAuthInfoForNewUser = oldAuthInfoForNewUser {
                loggedInUsersAuthInfo[index] = oldAuthInfoForNewUser
            } else {
                loggedInUsersAuthInfo.removeLast()
            }

            do {
                if let info = oldAuthInfo {
                    try writeActiveUserAuthInfoToStorage(activeAuthInfo: info, toStorage: storage)
                }
            } catch {
                // Do nothing
            }
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }

        self.activeUserAuthInfo = newAuthInfo
        self.activeUser = newUser
        return newUser
    }

    /**
     * Enum representing the keys for additional auth options that may be attached to the body of the authentication
     * request sent to the Stitch server on login or link.
     */
    private enum AuthKey: String {
        case options
        case device
    }

    /**
     * Attaches authentication options to the BSON document passed in as the `authBody` parameter. Necessary for the
     * the login request.
     */
    private func attachAuthOptions(authBody: inout Document) {
        authBody[AuthKey.options.rawValue] = [AuthKey.device.rawValue: deviceInfo] as Document
    }

    /**
     * Performs a request against the Stitch server to get the currently authenticated user's profile.
     */
    internal func doGetUserProfile() throws -> StitchUserProfile {
        let request = try StitchAuthRequestBuilder()
            .with(method: .get)
            .with(path: self.authRoutes.profileRoute)
            .build()

        let response = try doAuthenticatedRequest(request)

        var decodedProfile: APICoreUserProfileImpl!
        do {
            decodedProfile = try JSONDecoder.init().decode(APICoreUserProfileImpl.self, from: response.body!)
        } catch {
            throw StitchError.requestError(withError: error, withRequestErrorCode: .decodingError)
        }

        return StitchUserProfileImpl.init(userType: decodedProfile.userType,
                                          identities: decodedProfile.identities,
                                          data: decodedProfile.data)
    }
}
