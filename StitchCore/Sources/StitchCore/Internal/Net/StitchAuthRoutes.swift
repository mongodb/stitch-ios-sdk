public protocol StitchAuthRoutes {
    var sessionRoute: String { get }
    var profileRoute: String { get }

    func authProviderRoute(withProviderName providerName: String) -> String
    func authProviderLoginRoute(withProviderName providerName: String) -> String
    func authProviderLinkRoute(withProviderName providerName: String) -> String
}

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

public final class StitchServiceRoutes {
    private let clientAppId: String

    fileprivate init(clientAppId: String) {
        self.clientAppId = clientAppId
    }

    public lazy var functionCallRoute = String.init(format: RouteParts.functionCallRoute,
                                                    self.clientAppId)
}

public struct StitchAppAuthRoutes: StitchAuthRoutes {
    private let clientAppId: String

    public var sessionRoute: String = RouteParts.sessionRoute
    public var profileRoute: String = RouteParts.profileRoute

    fileprivate init(clientAppId: String) {
        self.clientAppId = clientAppId
    }

    public func authProviderRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderRoute,
                           self.clientAppId,
                           providerName)
    }

    public func authProviderLoginRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderLoginRoute,
                           self.clientAppId,
                           providerName)
    }

    public func authProviderLinkRoute(withProviderName providerName: String) -> String {
        return String.init(format: RouteParts.authProviderLinkRoute,
                           self.clientAppId,
                           providerName)
    }
}

public final class StitchAppRoutes {
    private let clientAppId: String

    public let authRoutes: StitchAppAuthRoutes
    public let serviceRoutes: StitchServiceRoutes

    public init(clientAppId: String) {
        self.clientAppId = clientAppId;
        self.authRoutes = StitchAppAuthRoutes.init(clientAppId: clientAppId)
        self.serviceRoutes = StitchServiceRoutes.init(clientAppId: clientAppId)
    }
}


