/**
 * A protocol defining the methods necessary to make authenticated requests to the Stitch server.
 */
public protocol StitchAuthRequestClient {
    /**
     * Performs an authenticated request to the Stitch server, using the current authentication state, and should
     * throw when not currently authenticated.
     *
     * - returns: The response to the request as a `Response`.
     */
    func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest

    /**
     * Performs an authenticated request to the Stitch server with a JSON request body, using the current
     * authentication state, and should throw when not currently authenticated.
     *
     * - returns: An `Any` representing the response body as decoded JSON.
     */
    func doAuthenticatedJSONRequest<T: Decodable>(_ stitchReq: StitchAuthDocRequest) throws -> T
}
