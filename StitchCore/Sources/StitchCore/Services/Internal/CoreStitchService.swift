import ExtendedJSON
import Foundation

/**
 * A class providing the core functionality necessary to make authenticated function call requests for a particular
 * Stitch service.
 */
open class CoreStitchService {

    // MARK: Properties

    /**
     * The `StitchAuthRequestClient` that this service will use to make authenticated requests to the Stitch server.
     */
    private let requestClient: StitchAuthRequestClient

    /**
     * The `StitchServiceRoutes` object representing the service API routes of the Stitch server for the current app.
     */
    private let serviceRoutes: StitchServiceRoutes

    /**
     * The name of the service that this `CoreStitchService` can make function calls for.
     */
    private let serviceName: String

    // MARK: Initializer

    /**
     * Initializes the service with the provided request client, routes, and service name.
     */
    public init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                name: String) {
        self.requestClient = requestClient
        self.serviceRoutes = routes
        self.serviceName = name
    }

    // MARK: Methods

    /**
     * Performs a request against the Stitch server to call a function of this service. Takes the function
     * name and arguments as parameters.
     *
     * - returns: An `Any` representing the decoded JSON of the result of the function call.
     */
    public func callFunctionInternal(withName name: String,
                                     withArgs args: BSONArray,
                                     withRequestTimeout requestTimeout: TimeInterval? = nil) throws -> Any {
        return try self.requestClient.doAuthenticatedJSONRequest(
            callFunctionRequest(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
        )
    }

    /**
     * Builds the request object necessary to make a function call against the Stitch server for this service. Takes
     * the function name and arguments as parameters.
     */
    private final func callFunctionRequest(withName name: String,
                                           withArgs args: BSONArray,
                                           withRequestTimeout requestTimeout: TimeInterval?) throws -> StitchAuthDocRequest {
        return try StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.path = self.serviceRoutes.functionCallRoute
            $0.timeout = requestTimeout
            $0.document = [
                "name": name,
                "service": self.serviceName,
                "arguments": args
            ]
        }.build()
    }
}
