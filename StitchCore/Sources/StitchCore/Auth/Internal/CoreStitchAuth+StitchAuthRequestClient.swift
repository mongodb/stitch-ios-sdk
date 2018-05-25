import Foundation
import MongoSwift

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
    public func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest {
        do {
            return try requestClient.doRequest(prepareAuthRequest(stitchReq))
        } catch let err {
            return try handleAuthFailure(forError: err, withRequest: stitchReq)
        }
    }
    
    public func doAuthenticatedRequest<RequestT, DecodedT>(_ stitchReq: RequestT) throws -> DecodedT
        where RequestT : StitchAuthRequest, DecodedT : Decodable {
        let response = try self.doAuthenticatedRequest(stitchReq)
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
                return try BsonDecoder().decode(DecodedT.self, from: responseString)
            } catch let err {
                throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
            }
        }
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
}
