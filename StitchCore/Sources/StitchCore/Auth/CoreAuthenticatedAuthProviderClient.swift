/**
 * :nodoc:
 * The class from which all Core authenticated auth provider clients inherit. Only auth provider clients that make
 * authenticated requests to the Stitch server need to inherit this class.
 */
open class CoreAuthenticatedAuthProviderClient {
    // MARK: Properties
    
    /**
     * The name of the authentication provider.
     */
    public let providerName: String
    
    /**
     * The `StitchAuthRequestClient` used by the client to make requests.
     */
    public let authRequestClient: StitchAuthRequestClient
    
    /**
     * The `StitchAuthRoutes` object representing the authentication API routes on the Stitch server.
     */
    public let authRoutes: StitchAuthRoutes
    
    // MARK: Initializer
    
    /**
     * A basic initializer, which sets the provider client's properties to the values provided in the parameters.
     */
    init(withProviderName providerName: String,
         withAuthRequestClient authRequestClient: StitchAuthRequestClient,
         withAuthRoutes authRoutes: StitchAuthRoutes) {
        self.providerName = providerName
        self.authRequestClient = authRequestClient
        self.authRoutes = authRoutes
    }
}

