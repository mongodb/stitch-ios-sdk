import Foundation

/**
 * A class representing the routes on the Stitch server to perform various actions related to the user API key
 * authentication provider.
 */
private final class Routes {
    /**
     * The authentication API routes that form the base of these provider routes.
     */
    private let authRoutes: StitchAuthRoutes
    
    /**
     * Initializes the routes with a `StitchAuthRoutes` and the name of the provider.
     */
    fileprivate init(withAuthRoutes authRoutes: StitchAuthRoutes) {
        self.authRoutes = authRoutes
    }

    fileprivate func apiKeyRoute(forKeyId id: String) -> String {
        return "\(authRoutes.apiKeysRoute)/\(id)"
    }
    
    fileprivate func apiKeyEnableRoute(forKeyId id: String) -> String {
        return "\(self.apiKeyRoute(forKeyId: id))/enable"
    }
    
    fileprivate func apiKeyDisableRoute(forKeyId id: String) -> String {
        return "\(self.apiKeyRoute(forKeyId: id))/disable"
    }
}

/**
 * :nodoc:
 * A client for the user API key authentication provider which can be used to obtain a credential for logging in.
 */
open class CoreUserAPIKeyAuthProviderClient {
    /**
     * The name of the provider.
     */
    private let providerName: String

    /**
     * Initializes this provider client with the name of the provider.
     */
    public init(withProviderName providerName: String = "api-key") {
        self.providerName = providerName
    }

    /**
     * Returns a credential for the provider, with the provided user API key.
     */
    public func credential(forKey key: String) -> UserAPIKeyCredential {
        return UserAPIKeyCredential(withProviderName: self.providerName, withKey: key)
    }
}

private let nameKey = "name"

/**
 * :nodoc:
 * A client for the user API key authentication provider which can be used to create and modify user API keys. This
 * client should only be used by an authenticatd user.
 */
open class CoreAuthenticatedUserAPIKeyAuthProviderClient {
    // MARK: Properties
    
    /**
     * The `StitchAuthRequestClient` used by the client to make requests.
     */
    public let authRequestClient: StitchAuthRequestClient
    
    /**
     * The `StitchAuthRoutes` object representing the authentication API routes on the Stitch server.
     */
    public let authRoutes: StitchAuthRoutes
    
    /**
     * The routes for the user API key CRUD operations.
     */
    private let routes: Routes
    
    // MARK: Initializer
    
    /**
     * A basic initializer, which sets the provider client's properties to the values provided in the parameters.
     */
    public init(withAuthRequestClient authRequestClient: StitchAuthRequestClient,
                withAuthRoutes authRoutes: StitchAuthRoutes) {
        self.authRequestClient = authRequestClient
        self.authRoutes = authRoutes
        self.routes = Routes.init(withAuthRoutes: authRoutes)
    }
    
    private func decode<T: Decodable>(fromResponse response: Response) throws -> T {
        do {
            return try JSONDecoder().decode(T.self,
                                            from: response.body!)
        } catch let err {
            throw StitchError.requestError(withError: err, withRequestErrorCode: .decodingError)
        }
    }
    
    /**
     * Creates a user API key that can be used to authenticate as the current user.
     *
     * - parameters:
     *     - withName: The name of the API key to be created.
     */
    public func createApiKey(withName name: String) throws -> UserAPIKey {
        return try decode(fromResponse: self.authRequestClient.doAuthenticatedJSONRequestRaw(
            StitchAuthDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [nameKey: name]
            $0.path = self.authRoutes.apiKeysRoute
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build()))
    }
    
    /**
     * Fetches a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to fetch.
     */
    public func fetchApiKey(withId id: String) throws -> UserAPIKey {
        return try decode(fromResponse: self.authRequestClient.doAuthenticatedRequest(
            StitchAuthRequestBuilderImpl {
            $0.method = .get
            $0.path = self.routes.apiKeyRoute(forKeyId: id)
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build()))
    }
    
    /**
     * Fetches the user API keys associated with the current user.
     */
    public func fetchApiKeys() throws -> [UserAPIKey] {
        return try decode(fromResponse: self.authRequestClient.doAuthenticatedRequest(
            StitchAuthRequestBuilderImpl {
            $0.method = .get
            $0.path = self.authRoutes.apiKeysRoute
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build()))
    }
    
    /**
     * Deletes a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to delete.
     */
    public func deleteApiKey(withId id: String) throws {
        _ = try self.authRequestClient.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.method = .delete
            $0.path = self.routes.apiKeyRoute(forKeyId: id)
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build())
    }
    
    /**
     * Enables a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to enable.
     */
    public func enableApiKey(withId id: String) throws {
        _ = try self.authRequestClient.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.method = .put
            $0.path = self.routes.apiKeyEnableRoute(forKeyId: id)
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build())
    }
    
    /**
     * Disables a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to disable.
     */
    public func disableApiKey(withId id: String) throws {
        _ = try self.authRequestClient.doAuthenticatedRequest(StitchAuthRequestBuilderImpl {
            $0.method = .put
            $0.path = self.routes.apiKeyDisableRoute(forKeyId: id)
            $0.shouldRefreshOnFailure = true
            $0.useRefreshToken = true
        }.build())
    }
}
