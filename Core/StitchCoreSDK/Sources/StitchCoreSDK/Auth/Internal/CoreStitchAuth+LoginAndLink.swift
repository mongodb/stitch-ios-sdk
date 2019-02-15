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
    public func loginInternal(withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        // Iterate over all logged in user to see if we can re-login
        if credential.providerCapabilities.reusesExistingSession {
            for user in allUsersAuthInfo {
                if type(of: credential).providerType == user.loggedInProviderType {
                    // Switch to this user --> it will persist auth changes
                    guard let userID = user.userID else {
                        throw StitchError.clientError(withClientErrorCode: .userNotValid)
                    }
                    return try switchToUserInternal(withID: userID)
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
    public func linkUserInternal(withUser user: TStitchUser,
                                 withCredential credential: StitchCredential) throws -> TStitchUser {
        objc_sync_enter(authOperationLock)
        defer { objc_sync_exit(authOperationLock) }

        guard let activeUser = self.activeUser, user == activeUser else {
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
        let previousUser = activeUser
        let user = try self.processLoginResponse(withCredential: credential,
                                                 forResponse: response,
                                                 asLinkRequest: asLinkRequest)
        if asLinkRequest {
            dispatchAuthEvent(.userLinked(linkedUser: user))
        } else {
            dispatchAuthEvent(.userLoggedIn(loggedInUser: user))
            dispatchAuthEvent(.activeUserChanged(currentActiveUser: activeUser,
                                                 previousActiveUser: previousUser))
        }
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
    // swiftlint:disable function_body_length
    internal func processLoginResponse(withCredential credential: StitchCredential,
                                       forResponse response: Response,
                                       asLinkRequest: Bool) throws -> TStitchUser {
        let decodedInfo = try decodeLoginResponse(response: response)

        // Preserve old auth info in case of profile request failure
        let oldAuthInfo = self.activeUserAuthInfo
        let oldUser = self.activeUser

        // Provisionally set auth info so we can make a profile request
        var apiAuthInfo = AuthInfo.init(
                userID: decodedInfo.userID,
                deviceID: decodedInfo.deviceID,
                accessToken: decodedInfo.accessToken,
                refreshToken: decodedInfo.refreshToken,
                loggedInProviderType: type(of: credential).providerType,
                loggedInProviderName: credential.providerName,
                lastAuthActivity: Date.init().timeIntervalSince1970)

        if let oldAuthInfo = oldAuthInfo {
            apiAuthInfo = oldAuthInfo.update(withNewAuthInfo: apiAuthInfo)
        }
        activeUserAuthInfo = apiAuthInfo

        // Get User Profile
        let profile = try getUserProfileOrProperlyFail(withCredential: credential,
                                         withOldAuthInfo: oldAuthInfo,
                                         withOldUser: oldUser,
                                         asLinkRequest: asLinkRequest)

        // Update the lastAuthActivity of the old active user
        if let oldAuthInfo = oldAuthInfo {
            if let oldIndex = allUsersAuthInfo.firstIndex(where: {$0.userID == oldAuthInfo.userID}) {
                allUsersAuthInfo[oldIndex] = oldAuthInfo.withNewAuthActivity
            }
        }

        // Finally make the new authInfo and user
        let newAuthInfo = apiAuthInfo.update(withUserProfile: profile,
                                             withLastAuthActivity: Date.init().timeIntervalSince1970)

        let newUserAdded = !self.allUsersAuthInfo.contains(newAuthInfo)
        let newUser = try makeStitchUser(withAuthInfo: newAuthInfo)

        // If the user already exists update it, otherwise append it to the list
        var index: Int = -1
        var oldAuthInfoForNewUser: AuthInfo?
        if let oldIndex = allUsersAuthInfo.firstIndex(where: {$0.userID == newAuthInfo.userID}) {
            index = oldIndex
            oldAuthInfoForNewUser = allUsersAuthInfo[index]
            allUsersAuthInfo[index] = newAuthInfo
        } else {
            index = allUsersAuthInfo.count
            allUsersAuthInfo.append(newAuthInfo)
        }

        // Persist auth info to storage, and return the resulting StitchUser
        do {
            try writeActiveUserAuthInfoToStorage(activeAuthInfo: newAuthInfo)
            try writeCurrentUsersAuthInfoToStorage()
        } catch {
            // Back out of setting authInfo
            self.activeUserAuthInfo = oldAuthInfo
            self.activeUser = oldUser
            if let info = oldAuthInfo {
                try? writeActiveUserAuthInfoToStorage(activeAuthInfo: info)
            }

            if let oldAuthInfoForNewUser = oldAuthInfoForNewUser {
                allUsersAuthInfo[index] = oldAuthInfoForNewUser
            } else {
                allUsersAuthInfo.removeLast()
            }
            try? writeCurrentUsersAuthInfoToStorage()

            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }

        self.activeUserAuthInfo = newAuthInfo
        self.activeUser = newUser

        if newUserAdded {
            dispatchAuthEvent(.userAdded(addedUser: newUser))
        }

        return newUser
    }
    // swiftlint:enable function_body_length

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

    /*
     * Processes the login response and outputs the relevant information
     * Attempt to shorten processLoginResponseFunction
     */
    internal func decodeLoginResponse(response: Response) throws -> APIAuthInfoImpl {
        guard let body = response.body else {
            throw StitchError.serviceError(
                withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                withServiceErrorCode: .unknown
            )
        }

        do {
            return try JSONDecoder().decode(APIAuthInfoImpl.self, from: body)
        } catch {
            throw StitchError.requestError(withError: error, withRequestErrorCode: .decodingError)
        }
    }

    /*
     * Calls doGetUserProfile() or propery fails
     * Attempt to shorten processLoginResponseFunction
     */
    internal func getUserProfileOrProperlyFail(withCredential credential: StitchCredential,
                                               withOldAuthInfo oldAuthInfo: AuthInfo?,
                                               withOldUser oldUser: TStitchUser?,
                                               asLinkRequest: Bool) throws -> StitchUserProfile {
        do {
            let profile = try doGetUserProfile()
            return profile
        } catch let err {
            // If this was a link request or another user is logged in, back out of setting authInfo
            // and reset any created user. This will keep the currently logged in user logged in if
            // the profile request failed, and in this particular edge case the user is linked,
            // but they are logged in with their older credentials.
            if asLinkRequest || oldAuthInfo != nil {
                self.activeUserAuthInfo = oldAuthInfo
                self.activeUser = oldUser

                if asLinkRequest, let oldAuthInfo = oldAuthInfo, oldAuthInfo.hasUser {
                    let newAuthInfo = AuthInfo.init(
                        userID: oldAuthInfo.userID,
                        deviceID: oldAuthInfo.deviceID,
                        accessToken: oldAuthInfo.accessToken,
                        refreshToken: oldAuthInfo.refreshToken,
                        loggedInProviderType: type(of: credential).providerType,
                        loggedInProviderName: credential.providerName,
                        userProfile: oldAuthInfo.userProfile,
                        lastAuthActivity: oldAuthInfo.lastAuthActivity)

                    try? updateActiveAuthInfo(withNewAuthInfo: newAuthInfo)
                }
            } else {
                try? updateActiveAuthInfo(withNewAuthInfo: nil)
            }

            throw err
        }
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
