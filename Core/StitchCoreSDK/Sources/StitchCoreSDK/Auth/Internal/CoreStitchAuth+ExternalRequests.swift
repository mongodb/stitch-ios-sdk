import Foundation
import MongoSwift

extension CoreStitchAuth {
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

        let oldAuthInfo = self.authInfo
        let oldUser = self.user

        // Provisionally set auth info so we can make a profile request
        var newAPIAuthInfo: APIAuthInfo!
        if let oldAuthInfo = oldAuthInfo { // If there was existing auth info (as in a link request)
            let newAuthInfo = oldAuthInfo.merge(
                withPartialInfo: decodedInfo,
                fromOldInfo: oldAuthInfo
            )
            newAPIAuthInfo = newAuthInfo

            self.authInfo = newAuthInfo
        } else { // If there was no existing auth info
            newAPIAuthInfo = decodedInfo
            self.authStateHolder.apiAuthInfo = decodedInfo
        }

        var profile: StitchUserProfile!
        do {
            profile = try doGetUserProfile()
        } catch let err {
            // If this was a link request, back out of setting authInfo and reset any created user. This will keep
            // the currently logged in user logged in if the profile request failed, and in this particular edge case
            // the user is linked, but they are logged in with their older credentials.
            if asLinkRequest {
                self.authInfo = oldAuthInfo
                currentUser = oldUser
            } else { // otherwise if this was a normal login request, log the user out
                self.authInfo = nil
                currentUser = nil
            }

            throw err
        }

        // Finally set the info and user
        self.authInfo = StoreAuthInfo.init(
            withAPIAuthInfo: newAPIAuthInfo,
            withExtendedAuthInfo: ExtendedAuthInfoImpl.init(loggedInProviderType: type(of: credential).providerType,
                                                            loggedInProviderName: credential.providerName,
                                                            userProfile: profile))

        // Persist auth info to storage, and return the resulting StitchUser
        return try persistAuthInfoToStorage(forCredential: credential, withProfile: profile)
    }

    private func persistAuthInfoToStorage(
        forCredential credential: StitchCredential,
        withProfile profile: StitchUserProfile
    ) throws -> TStitchUser {
        // Persist auth info to storage
        do {
            try self.authInfo?.write(toStorage: &storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }

        self.currentUser =
            userFactory
                .makeUser(
                    withID: authInfo!.userID,
                    withLoggedInProviderType: type(of: credential).providerType,
                    withLoggedInProviderName: credential.providerName,
                    withUserProfile: profile)
        return self.currentUser!
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
        let response = try doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .with(method: .get)
                .with(path: self.authRoutes.profileRoute)
                .build()
        )

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

    /**
     * Performs a logout request against the Stitch server.
     */
    @discardableResult
    internal func doLogout() throws -> Response {
        return try self.doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .withRefreshToken()
                .with(path: authRoutes.sessionRoute)
                .with(method: .delete)
                .build()
        )
    }

    /**
     * Performs the request necessary to refresh an access token.
     *
     * - return: a new APIAccessToken representing the refreshed access token.
     */
    internal func doRefreshAccessToken() throws -> APIAccessToken {
        let response = try self.doAuthenticatedRequest(
            StitchAuthRequestBuilder()
                .withRefreshToken()
                .with(path: self.authRoutes.sessionRoute)
                .with(method: .post)
                .build()
        )

        var newAccessToken: APIAccessToken!
        do {
            newAccessToken = try JSONDecoder().decode(APIAccessToken.self,
                                                      from: response.body!)
        } catch let err {
            throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
        }

        return newAccessToken
    }
}
