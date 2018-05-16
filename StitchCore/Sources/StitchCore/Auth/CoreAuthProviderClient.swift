import Foundation

open class CoreAuthProviderClient<RequestClientType> {
    // MARK: Properties

    /**
     * The name of the authentication provider.
     */
    public let providerName: String

    /**
     * The request client used by the client to make requests. Is generic since some auth provider clients use an
     * authenticated request client while others use an unauthenticated request client.
     */
    public let requestClient: RequestClientType

    /**
     * The base route for this authentication provider client.
     */
    public let baseRoute: String

    /**
     * Performs a basic decoding of the provided HTTP response with a `JSONDecoder`.
     */
    public func decode<T: Decodable>(fromResponse response: Response) throws -> T {
        do {
            return try JSONDecoder().decode(T.self,
                                            from: response.body!)
        } catch let err {
            throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
        }
    }

    // MARK: Initializer

    /**
     * A basic initializer, which sets the provider client's properties to the values provided in the parameters.
     */
    init(withProviderName providerName: String,
         withRequestClient requestClient: RequestClientType,
         withBaseRoute baseRoute: String) {
        self.providerName = providerName
        self.requestClient = requestClient
        self.baseRoute = baseRoute
    }
}
