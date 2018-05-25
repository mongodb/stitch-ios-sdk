import Foundation

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
    func doAuthenticatedRequest<RequestT>(_ stitchReq: RequestT) throws -> Response where RequestT: StitchAuthRequest
    
    /**
     * Performs an authenticated request to the Stitch server, using the current authentication state, and should
     * throw when not currently authenticated. Decodes the response body into a `Decodable` type based on the
     * `DecodedT`  type parameter.
     *
     * - returns: The decoded body of the response.
     */
    func doAuthenticatedRequest<RequestT, DecodedT: Decodable>(_ stitchReq: RequestT) throws -> DecodedT where RequestT: StitchAuthRequest
}
