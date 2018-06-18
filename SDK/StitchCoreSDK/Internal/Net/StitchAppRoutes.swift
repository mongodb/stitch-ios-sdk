/**
 * Static class containing the base componenets of all the Stitch routes.
 */
internal final class StitchAppRouteParts {
    static let baseRoute = "/api/client/v2.0"
    static let appRoute = baseRoute + "/app/%@"
    static let functionCallRoute = appRoute + "/functions/call"
    static let baseAuthRoute = baseRoute + "/auth"
    static let baseAppAuthRoute = appRoute + "/auth"

    static let sessionRoute = baseAuthRoute + "/session"
    static let profileRoute = baseAuthRoute + "/profile"
    static let authProviderRoute = baseAppAuthRoute + "/providers/%@"
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
     * The base route on the server for authentication-related actions.
     */
    var baseAuthRoute: String { get }

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
    private let clientAppID: String

    /**
     * Initializes these routes with the provided client app id.
     */
    fileprivate init(clientAppID: String) {
        self.clientAppID = clientAppID
    }

    /**
     * Returns the route on the server for executing a function.
     */
    public lazy var functionCallRoute = String.init(format: StitchAppRouteParts.functionCallRoute,
                                                    self.clientAppID)
}

/**
 * A struct representing the authentication API routes on the Stitch server for a particular app.
 */
public struct StitchAppAuthRoutes: StitchAuthRoutes {
    /**
     * The client app id of the app that these routes are for.
     */
    private let clientAppID: String

    /**
     * The route on the server for getting a new access token.
     */
    public var sessionRoute: String = StitchAppRouteParts.sessionRoute

    /**
     * The route on the server for fetching the currently authenticated user's profile.
     */
    public var profileRoute: String = StitchAppRouteParts.profileRoute

    /**
     * The route on the server for creating and modifying user API keys.
     */
    public var baseAuthRoute: String = StitchAppRouteParts.baseAuthRoute

    /**
     * Initializes these routes with the provided client app id.
     */
    fileprivate init(clientAppID: String) {
        self.clientAppID = clientAppID
    }

    /**
     * Returns the route on the server for getting information about a particular authentication provider.
     */
    public func authProviderRoute(withProviderName providerName: String) -> String {
        return String.init(format: StitchAppRouteParts.authProviderRoute,
                           self.clientAppID,
                           providerName)
    }

    /**
     * Returns the route on the server for logging in with a particular authentication provider.
     */
    public func authProviderLoginRoute(withProviderName providerName: String) -> String {
        return String.init(format: StitchAppRouteParts.authProviderLoginRoute,
                           self.clientAppID,
                           providerName)
    }

    /**
     * Returns the route on the server for linking the currently authenticated user with an identity associated with a
     * particular authentication provider.
     */
    public func authProviderLinkRoute(withProviderName providerName: String) -> String {
        return String.init(format: StitchAppRouteParts.authProviderLinkRoute,
                           self.clientAppID,
                           providerName)
    }
}

/**
 * A class representing all API routes on the Stitch server for a particular app.
 */
public final class StitchAppRoutes {
    /**
     * Returns the authentication routes for the current app.
     */
    public let authRoutes: StitchAppAuthRoutes

    /**
     * Returns the service routes for the current app.
     */
    public let serviceRoutes: StitchServiceRoutes
    
    /**
     * Returns the push routes for the current app.
     */
    public let pushRoutes: StitchPushRoutes

    /**
     * Initializes the app routes with the provided client app id.
     */
    public init(clientAppID: String) {
        self.authRoutes = StitchAppAuthRoutes.init(clientAppID: clientAppID)
        self.serviceRoutes = StitchServiceRoutes.init(clientAppID: clientAppID)
        self.pushRoutes = StitchPushRoutes.init(clientAppID: clientAppID)
    }
}
