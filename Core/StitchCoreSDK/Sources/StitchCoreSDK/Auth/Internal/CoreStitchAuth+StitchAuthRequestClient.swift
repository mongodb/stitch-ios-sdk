import Foundation
import MongoSwift

private let authTokenQueryParam = "&stitch_at="

/**
 * Extension functions for `CoreStitchAuth` to add conformance to `StitchAuthRequestClient`, and to support proactive
 * and non-proactive access token refresh.
 */
extension CoreStitchAuth {
    /**
     * Performs an authenticated request to the Stitch server, using the current authentication state. Will throw when
     * when the `CoreStitchAuth` is not currently authenticated.
     *
     * - returns: The response to the request as a `Response`.
     */
    public func doAuthenticatedRequest(_ stitchReq: StitchAuthRequest) throws -> Response {
        do {
            guard stitchReq.headers.index(forKey: Headers.authorization.rawValue) != nil else {
                return try requestClient.doRequest(prepareAuthRequest(withAuthRequest: stitchReq,
                                                                      withAuthInfo: nil))
            }
            return try requestClient.doRequest(stitchReq)
        } catch let err {
            return try handleAuthFailure(forError: err, withRequest: stitchReq)
        }
    }

    public func doAuthenticatedRequest<T: Decodable>(_ stitchReq: StitchAuthRequest) throws -> T {
        let response = try self.doAuthenticatedRequest(stitchReq)
        do {
            guard let responseBody = response.body,
                let responseString = String.init(data: responseBody, encoding: .utf8) else {
                    throw StitchError.serviceError(
                        withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                        withServiceErrorCode: .unknown)
            }

            do {
                return try BSONDecoder().decode(T.self, from: responseString)
            } catch let err {
                throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
            }
        }
    }

    public func doAuthenticatedRequestOptionalResult<T: Decodable>(_ stitchReq: StitchAuthRequest) throws -> T? {
        let response = try self.doAuthenticatedRequest(stitchReq)
        do {
            guard let responseBody = response.body,
                let responseString = String.init(data: responseBody, encoding: .utf8) else {
                    throw StitchError.serviceError(
                        withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                        withServiceErrorCode: .unknown)
            }

            do {
                return try BSONDecoder().decode(T.self, from: responseString)
            } catch {
                return nil
            }
        }
    }

    public func openAuthenticatedStream(
        _ stitchReq: StitchAuthRequest,
        delegate: SSEStreamDelegate? = nil
    ) throws -> RawSSEStream {
        guard isLoggedIn,
            let authInfo = self.activeUserAuthInfo,
            let authToken = stitchReq.useRefreshToken
                ? authInfo.refreshToken : authInfo.accessToken else {
            throw StitchError.clientError(withClientErrorCode: .mustAuthenticateFirst)
        }

        do {
            return try requestClient.doStreamRequest(
                stitchReq.builder.with(path: stitchReq.path +
                    authTokenQueryParam +
                    authToken).build(), delegate: delegate)
        } catch {
            return try handleAuthFailureForStream(forError: error, withRequest: stitchReq)
        }
    }

    /**
     * Prepares an authenticated Stitch request by attaching the `CoreStitchAuth`'s current access or refresh token
     * (depending on the type of request) to the request's `"Authorization"` header.
     */
    public func prepareAuthRequest(withAuthRequest stitchReq: StitchAuthRequest,
                                   withAuthInfo authInfo: AuthInfo?) throws -> StitchRequest {
        objc_sync_enter(authStateLock)
        defer { objc_sync_exit(authStateLock) }

        guard let loggedIn = authInfo != nil ?  authInfo?.isLoggedIn : self.isLoggedIn, loggedIn,
            let refreshToken = authInfo != nil ? authInfo?.refreshToken : activeUserAuthInfo?.refreshToken,
            let accessToken = authInfo != nil ? authInfo?.accessToken : activeUserAuthInfo?.accessToken else {
                throw StitchError.clientError(withClientErrorCode: .mustAuthenticateFirst)
        }

        let reqBuilder = StitchRequestBuilder()
        var newHeaders = stitchReq.headers
        if stitchReq.useRefreshToken {
            newHeaders[Headers.authorization.rawValue] =
                Headers.authorizationBearer(forValue: refreshToken)
        } else {
            newHeaders[Headers.authorization.rawValue] =
                Headers.authorizationBearer(forValue: accessToken)
        }

        reqBuilder
            .with(headers: newHeaders)
            .with(path: stitchReq.path)
            .with(method: stitchReq.method)

        if let body = stitchReq.body {
            reqBuilder.with(body: body)
        }

        if let timeout = stitchReq.timeout {
            reqBuilder.with(timeout: timeout)
        }

        return try reqBuilder.build()
    }

    /**
     * Checks the `Error` object provided in the `forError` parameter, and if it's an error indicating an invalid
     * Stitch session, it will handle the error by attempting to refresh the access token if it hasn't been attempted
     * already. If the error is not a Stitch error, or the error is a Stitch error not related to an invalid session,
     * it will be re-thrown.
     */
    private func handleAuthFailure(forError error: Error,
                                   withRequest req: StitchAuthRequest) throws -> Response {
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
            try? self.clearUserAuthToken(forUserID: activeUserAuthInfo?.userID ?? "")
            throw error
        }

        try self.tryRefreshAccessToken(reqStartedAt: req.startedAt)

        return try doAuthenticatedRequest(req.builder.with(shouldRefreshOnFailure: false).build())
    }

    private func handleAuthFailureForStream(forError error: Error,
                                            withRequest req: StitchAuthRequest) throws -> RawSSEStream {
        // this block is to check whether the error is due to an invalid Stitch session.
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
            try? self.clearUserAuthToken(forUserID: activeUserAuthInfo?.userID ?? "")
            throw error
        }

        try self.tryRefreshAccessToken(reqStartedAt: req.startedAt)

        return try openAuthenticatedStream(req.builder.with(shouldRefreshOnFailure: false).build())
    }
}
