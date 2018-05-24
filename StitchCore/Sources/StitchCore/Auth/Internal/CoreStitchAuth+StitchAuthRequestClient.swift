import Foundation
import MongoSwift

/**
 * Extension functions for `CoreStitchAuth` to add conformance to `StitchAuthRequestClient`, and to support proactive
 * and non-proactive access token refresh.
 */
extension CoreStitchAuth: StitchAuthRequestClient {
    /**
     * Performs an authenticated request to the Stitch server, using the current authentication state. Will throw when
     * when the `CoreStitchAuth` is not currently authenticated.
     *
     * - returns: The response to the request as a `Response`.
     */
    public func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest {
        do {
            return try requestClient.doRequest(prepareAuthRequest(stitchReq))
        } catch let err {
            return try handleAuthFailure(forError: err, withRequest: stitchReq)
        }
    }

    /**
     * Performs an authenticated request to the Stitch server with a JSON body. Uses the current authentication state,
     * and will throw when the `CoreStitchAuth` is not currently authenticated.
     *
     * - returns: A `T` representing the response body as decoded JSON.
     */
    public func doAuthenticatedJSONRequest<T: Decodable>(_ stitchReq: StitchAuthDocRequest) throws -> T {
        func handleResponse(_ response: Response) throws -> T {
            do {
                guard let responseBody = response.body,
                    let responseString = String.init(data: responseBody, encoding: .utf8) else {
                    throw StitchError.serviceError(
                        withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                        withServiceErrorCode: .unknown
                    )
                }

                do {
                    // TODO: until Swift Driver decides on what to do
                    return try BsonDecoder().decode(T.self, from: responseString)
                } catch let err {
                    throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
                }
            } catch let err {
                return try handleResponse(handleAuthFailure(forError: err,
                                                            withRequest: stitchReq))
            }
        }
        
        return try handleResponse(doAuthenticatedJSONRequestRaw(stitchReq))
    }

    /**
     * The underlying logic of performing the authenticated JSON request to the Stitch server.
     *
     * - returns: The response to the request as a `Response`.
     */
    internal func doAuthenticatedJSONRequestRaw(_ stitchReq: StitchAuthDocRequest) throws -> Response {
        var builder = StitchAuthDocRequestBuilderImpl { _ in }
        builder.path = stitchReq.path
        builder.useRefreshToken = stitchReq.useRefreshToken
        builder.method = stitchReq.method
        builder.body = stitchReq.document.canonicalExtendedJSON.data(using: .utf8)
        builder.timeout = stitchReq.timeout
        builder.document = stitchReq.document
        builder.headers = stitchReq.headers.merging(
            [Headers.contentType.rawValue:
                ContentTypes.applicationJson.rawValue]
        ) { current, _ in current }
        return try self.doAuthenticatedRequest(builder.build())
    }

    /**
     * Prepares an authenticated Stitch request by attaching the `CoreStitchAuth`'s current access or refresh token
     * (depending on the type of request) to the request's `"Authorization"` header.
     */
    private func prepareAuthRequest<R>(_ stitchReq: R) throws -> StitchRequestImpl where R: StitchAuthRequest {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard self.isLoggedIn,
            let refreshToken = self.authStateHolder.refreshToken,
            let accessToken = self.authStateHolder.accessToken else {
                throw StitchError.clientError(withClientErrorCode: .mustAuthenticateFirst)
        }

        return try StitchRequestBuilderImpl {
            var newHeaders = stitchReq.headers
            if stitchReq.useRefreshToken {
                newHeaders[Headers.authorization.rawValue] =
                    Headers.authorizationBearer(forValue: refreshToken)
            } else {
                newHeaders[Headers.authorization.rawValue] =
                    Headers.authorizationBearer(forValue: accessToken)
            }
            $0.headers = newHeaders
            $0.path = stitchReq.path
            $0.method = stitchReq.method
            $0.body = stitchReq.body
            $0.timeout = stitchReq.timeout
        }.build()
    }

    /**
     * Checks the `Error` object provided in the `forError` parameter, and if it's an error indicating an invalid
     * Stitch session, it will handle the error by attempting to refresh the access token if it hasn't been attempted
     * already. If the error is not a Stitch error, or the error is a Stitch error not related to an invalid session,
     * it will be re-thrown.
     */
    private func handleAuthFailure<R>(forError error: Error,
                                      withRequest req: R) throws -> Response where R: StitchAuthRequest {
        guard let sError = error as? StitchError else {
            throw error
        }

        switch sError {
        case .serviceError(_, let withErrorCode):
            guard withErrorCode == .invalidSession else {
                throw error
            }
        default:
            throw error
        }

        // using a refresh token implies we cannot refresh anything, so clear auth and
        // notify
        if req.useRefreshToken || !req.shouldRefreshOnFailure {
            self.clearAuth()
            throw error
        }

        try self.tryRefreshAccessToken(reqStartedAt: req.startedAt)

        return try doAuthenticatedRequest(req)
    }

    /**
     * Checks if the current access token is expired or going to expire soon, and refreshes the access token if
     * necessary.
     */
    internal func tryRefreshAccessToken(reqStartedAt: TimeInterval) throws {
        // use this critical section to create a queue of pending outbound requests
        // that should wait on the result of doing a token refresh or logout. This will
        // prevent too many refreshes happening one after the other.
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard isLoggedIn, let accessToken = self.authStateHolder.accessToken else {
            throw StitchError.clientError(withClientErrorCode: .loggedOutDuringRequest)
        }

        let jwt = try JWT.init(fromEncodedJWT: accessToken)
        guard let issuedAt = jwt.issuedAt,
            issuedAt < reqStartedAt else {
            return
        }
        try refreshAccessToken()
    }

    /**
     * Attempts to refresh the current access token.
     *
     * - important: This method must be called within a lock.
     */
    internal func refreshAccessToken() throws {
        let response = try self.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.useRefreshToken = true
            $0.path = self.authRoutes.sessionRoute
            $0.method = .post
            }.build())

        var newAccessToken: APIAccessToken!
        do {
            newAccessToken = try JSONDecoder().decode(APIAccessToken.self,
                                                      from: response.body!)
        } catch let err {
            throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
        }

        self.authInfo = self.authInfo?.refresh(withNewAccessToken: newAccessToken)

        do {
            try self.authInfo?.write(toStorage: &self.storage)
        } catch {
            throw StitchError.clientError(withClientErrorCode: .couldNotPersistAuthInfo)
        }
    }
}
