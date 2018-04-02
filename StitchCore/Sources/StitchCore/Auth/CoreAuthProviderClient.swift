/**
 * :nodoc:
 * The class from which all Core auth provider clients inherit. Only auth provider clients that make requests
 * to the Stitch server need to inherit this class.
 */
open class CoreAuthProviderClient {
    // MARK: Properties

    /**
     * The name of the authentication provider.
     */
    public let providerName: String

    /**
     * The `StitchRequestClient` used by the client to make requests.
     */
    public let requestClient: StitchRequestClient

    /**
     * The `StitchAuthRoutes` object representing the authentication API routes on the Stitch server.
     */
    public let authRoutes: StitchAuthRoutes

    // MARK: Initializer

    /**
     * A basic initializer, which sets the provider client's properties to the values provided in the parameters.
     */
    init(withProviderName providerName: String,
         withRequestClient requestClient: StitchRequestClient,
         withAuthRoutes authRoutes: StitchAuthRoutes) {
        self.providerName = providerName
        self.requestClient = requestClient
        self.authRoutes = authRoutes
    }
}
