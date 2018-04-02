/**
 * Static class containing the base componenets of all the Stitch routes.
 */
private final class RouteParts {
    static let baseRoute = "/api/client/v2.0"
    static let appRoute = baseRoute + "/app/%@"
    static let functionCallRoute = appRoute + "/functions/call"

    static let sessionRoute = baseRoute + "/auth/session"
    static let profileRoute = baseRoute + "/auth/profile"
    static let authProviderRoute = appRoute + "/auth/providers/%@"
    static let authProviderLoginRoute = authProviderRoute + "/login"
    static let authProviderLinkRoute = authProviderLoginRoute + "?link=true"
}

/**
 * A protocol representing the authentication API routes on the Stitch server.
 */
public protocol StitchAuthRoutes {
    /**
     * The route on the server for getting a new access token.
     */
    var sessionRoute: String { get }

    /**
     * The route on the server for fetching the currently authenticated user's profile.
     */
    var profileRoute: String { get }

    /**
     * Returns the route on the server for getting information about a particular authentication provider.
     */
    func authProviderRoute(withProviderName providerName: String) -> String

    /**
     * Returns the route on the server for logging in with a particular authentication provider.
     */
    func authProviderLoginRoute(withProviderName providerName: String) -> String

    /**
     * Returns the route on the server for linking the currently authenticated user with an identity associated with a
     * particular authentication provider.
     */
    func authProviderLinkRoute(withProviderName providerName: String) -> String
}

/**
 * A class representing the service API routes on the Stitch server for a particular app.
 */
public final class StitchServiceRoutes {
    /**
     * The client app id of the app that these routes are for.
     */
    private let clientAppId: String

    /**
     * Initializes these routes with the provided client app id.
     */
    fileprivate init(clientAppId: String) {
        self.clientAppId = clientAppId
    }

    /**
     * Returns the route on the server for executing a function.
     */
    public lazy var functionCallRoute = String.init(format: RouteParts.functionCallRoute,
                                                    self.clientAppId)
}

/**
 * A struct representing the authentication API routes on the Stitch server for a particular app.
 */
public struct StitchAppAuthRoutes: StitchAuthRoutes {
    /**
     * The client app id of the app that these routes are for.
     */
    private let clientAppId: String

    /**
     * The route on the server for getting a new access token.
     */
    public var sessionRoute: String = RouteParts.sessionRoute

    /**
     * The route on the server for fetching the currently authenticated user's profile.
     */
    public var profileRoute: String = RouteParts.profileRoute

    /**
     * Initializes these routes with the provided client app id.
     */
    fileprivate init(clientAppId: String) {
        self.clientAppId = clientAppId
    }

    /**
     * Returns the route on the server for getting information about a particular authentication provider.
     */
    public func authProviderRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderRoute,
                           self.clientAppId,
                           providerName)
    }

    /**
     * Returns the route on the server for logging in with a particular authentication provider.
     */
    public func authProviderLoginRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderLoginRoute,
                           self.clientAppId,
                           providerName)
    }

    /**
     * Returns the route on the server for linking the currently authenticated user with an identity associated with a
     * particular authentication provider.
     */
    public func authProviderLinkRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderLinkRoute,
                           self.clientAppId,
                           providerName)
    }
}

/**
 * A class representing all API routes on the Stitch server for a particular app.
 */
public final class StitchAppRoutes {
    /**
     * The client app id of the app that these routes are for.
     */
    private let clientAppId: String

    /**
     * Returns the authentication routes for the current app.
     */
    public let authRoutes: StitchAppAuthRoutes

    /**
     * Returns the service routes for the current app.
     */
    public let serviceRoutes: StitchServiceRoutes

    /**
     * Initializes the app routes with the provided client app id.
     */
    public init(clientAppId: String) {
        self.clientAppId = clientAppId
        self.authRoutes = StitchAppAuthRoutes.init(clientAppId: clientAppId)
        self.serviceRoutes = StitchServiceRoutes.init(clientAppId: clientAppId)
    }
}
