import MongoSwift
import Foundation

/**
 * A class providing the core functionality necessary for a Stitch app client to make authenticated function call
 * requests.
 */
public final class CoreStitchAppClient {

    // MARK: Properties

    /**
     * the `CoreStitchServiceClient` that will be used to make function call requests to Stitch.
     */
    private let functionService: CoreStitchServiceClient
    
    // MARK: Initializer
    
    /**
     * Initializes the app client with the provided `StitchAuthRequestClient` and `StitchAppRoutes`.
     */
    public init(authRequestClient: StitchAuthRequestClient, routes: StitchAppRoutes) {
        self.functionService = CoreStitchServiceClientImpl.init(requestClient: authRequestClient,
                                                          routes: routes.serviceRoutes,
                                                          serviceName: nil)
    }

    // MARK: Methods
    /**
     * Performs a request against the Stitch server to call a function in the Stitch application. Takes the function
     * name and arguments as parameters.
     */
    public func callFunction(withName name: String,
                                     withArgs args: [BsonValue],
                                     withRequestTimeout requestTimeout: TimeInterval? = nil) throws {
        try self.functionService.callFunction(withName: name,
                                                      withArgs: args,
                                                      withRequestTimeout: requestTimeout)
    }
    
    /**
     * Performs a request against the Stitch server to call a function in the Stitch application. Takes the function
     * name and arguments as parameters.
     *
     * - returns: A `T` representing the decoded JSON of the result of the function call.
     */
    public func callFunction<T: Decodable>(withName name: String,
                                                   withArgs args: [BsonValue],
                                                   withRequestTimeout requestTimeout: TimeInterval? = nil) throws -> T {
        return try self.functionService.callFunction(withName: name,
                                                             withArgs: args,
                                                             withRequestTimeout: requestTimeout)
    }
}
