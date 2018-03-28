/** :nodoc: */
open class CoreAuthProviderClient {
    public let providerName: String
    public let requestClient: StitchRequestClient
    public let authRoutes: StitchAuthRoutes

    init(withProviderName providerName: String,
         withRequestClient requestClient: StitchRequestClient,
         withAuthRoutes authRoutes: StitchAuthRoutes) {
        self.providerName = providerName
        self.requestClient = requestClient
        self.authRoutes = authRoutes
    }
}
