import Foundation

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
     * - returns: An `Any` representing the response body as decoded JSON.
     */
    public func doAuthenticatedJSONRequest(_ stitchReq: StitchAuthDocRequest) throws -> Any {
        do {
            let response = try doAuthenticatedJSONRequestRaw(stitchReq)

            guard let responseBody = response.body else {
                throw StitchError.requestError(withMessage: "no body in request response")
            }

            return try JSONSerialization.jsonObject(with: responseBody,
                                                    options: JSONSerialization.ReadingOptions.allowFragments)

        } catch let err {
            return try handleAuthFailure(forError: err, withRequest: stitchReq) as Any
        }
    }

    /**
     * The underlying logic of performing the authenticated JSON request to the Stitch server.
     *
     * - returns: The response to the request as a `Response`.
     */
    public func doAuthenticatedJSONRequestRaw(_ stitchReq: StitchAuthDocRequest) throws -> Response {
        var builder = StitchAuthDocRequestBuilderImpl { _ in }
        builder.path = stitchReq.path
        builder.useRefreshToken = stitchReq.useRefreshToken
        builder.method = stitchReq.method
        builder.body = try JSONSerialization.data(withJSONObject: stitchReq.document.toExtendedJSON)
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
        return try sync(self) {
            guard self.isLoggedIn,
                let refreshToken = self.authStateHolder.refreshToken,
                let accessToken = self.authStateHolder.accessToken else {
                    throw StitchClientError.mustAuthenticateFirst
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
                }.build()
        }
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
        case .requestError:
            throw error
        }

        // using a refresh token implies we cannot refresh anything, so clear auth and
        // notify
        if req.useRefreshToken || !req.shouldRefreshOnFailure {
            try self.clearAuth()
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
        try sync(self) {
            guard isLoggedIn, let accessToken = self.authStateHolder.accessToken else {
                throw StitchError.requestError(withMessage: "logged out during request")
            }

            let jwt = try DecodedJWT.init(jwt: accessToken)
            guard let issuedAt = jwt.issuedAt,
                issuedAt.timeIntervalSince1970 < reqStartedAt else {
                    return
            }
            try refreshAccessToken()
        }
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

        let newAccessToken = try JSONDecoder().decode(APIAccessToken.self,
                                                      from: response.body!)

        self.authInfo = self.authInfo?.refresh(withNewAccessToken: newAccessToken)

        try self.authInfo?.write(toStorage: &self.storage)
    }
}
