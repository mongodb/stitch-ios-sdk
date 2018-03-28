import Foundation

extension CoreStitchAuth: StitchAuthRequestClient {
    public func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest {
        do {
            return try requestClient.doRequest(prepareAuthRequest(stitchReq))
        } catch let err {
            return try handleAuthFailure(forError: err, withRequest: stitchReq)
        }
    }

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

    private func prepareAuthRequest<R>(_ stitchReq: R) throws -> StitchRequestImpl where R: StitchAuthRequest {
        return try sync(self) {
            guard self.isLoggedIn,
                let refreshToken = self.authStateHolder.refreshToken,
                let accessToken = self.authStateHolder.accessToken else {
                    throw StitchClientErrors.mustAuthenticateFirst
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

    // Will propagate non-Stitch errors, and Stitch errors that aren't related to authentication failure
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
}
