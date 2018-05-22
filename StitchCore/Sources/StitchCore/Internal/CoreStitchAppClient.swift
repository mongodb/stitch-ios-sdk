import BSON
import Foundation

/**
 * A class providing the core functionality necessary for a Stitch app client to make authenticated function call
 * requests.
 */
public final class CoreStitchAppClient {

    // MARK: Properties

    /**
     * The `StitchAuthRequestClient` that this app client will use to make authenticated requests to the Stitch server.
     */
    private let authRequestClient: StitchAuthRequestClient

    /**
     * The `StitchAppRoutes` object representing the API routes of the Stitch server for the current app.
     */
    private let routes: StitchAppRoutes

    // MARK: Initializer

    /**
     * Initializes the app client with the provided `StitchAuthRequestClient` and `StitchAppRoutes`.
     */
    public init(authRequestClient: StitchAuthRequestClient, routes: StitchAppRoutes) {
        self.authRequestClient = authRequestClient
        self.routes = routes
    }

    // MARK: Methods
    /**
     * Performs a request against the Stitch server to call a function in the Stitch application. Takes the function
     * name and arguments as parameters.
     *
     * - returns: An `Any` representing the decoded JSON of the result of the function call.
     */
    public func callFunctionInternal(withName name: String,
                                     withArgs args: [BsonValue],
                                     withRequestTimeout requestTimeout: TimeInterval? = nil) throws {
        let _ = try self.authRequestClient.doAuthenticatedRequest(
            callFunctionRequest(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        )
    }
    
    /**
     * Performs a request against the Stitch server to call a function in the Stitch application. Takes the function
     * name and arguments as parameters.
     *
     * - returns: An `Any` representing the decoded JSON of the result of the function call.
     */
    public func callFunctionInternal<D: Decodable>(withName name: String,
                                                   withArgs args: [BsonValue],
                                                   withRequestTimeout requestTimeout: TimeInterval? = nil) throws -> D {
        return try self.authRequestClient.doAuthenticatedJSONRequest(
            callFunctionRequest(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        )
    }

    /**
     * Builds the request object necessary to make a function call against the Stitch server. Takes the function name
     * and arguments as parameters.
     */
    private func callFunctionRequest(withName name: String,
                                     withArgs args: [BsonValue],
                                     withRequestTimeout requestTimeout: TimeInterval?) throws -> StitchAuthDocRequest {
        let route = self.routes.serviceRoutes.functionCallRoute
        return try StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.path = route
            $0.timeout = requestTimeout
            $0.document = [
                "name": name,
                "arguments": args
            ]
        }.build()
    }
}
