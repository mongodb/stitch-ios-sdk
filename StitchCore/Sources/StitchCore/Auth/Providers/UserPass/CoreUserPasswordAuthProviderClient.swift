private final class Routes {
    private let authRoutes: StitchAuthRoutes
    private let providerName: String

    fileprivate init(withAuthRoutes authRoutes: StitchAuthRoutes,
                     withProviderName providerName: String) {
        self.authRoutes = authRoutes
        self.providerName = providerName
    }

    private func extensionRoute(forPath path: String) -> String {
        return "\(authRoutes.authProviderLoginRoute(withProviderName: providerName))/\(path)"
    }

    fileprivate lazy var registerWithEmailRoute = self.extensionRoute(forPath: "register")

    fileprivate lazy var confirmUserRoute = self.extensionRoute(forPath: "confirm")

    fileprivate lazy var resendConfirmationEmailRoute = self.extensionRoute(forPath: "confirm/send")

    fileprivate lazy var resetPasswordRoute = self.extensionRoute(forPath: "reset")

    fileprivate lazy var sendResetPasswordEmailRoute = self.extensionRoute(forPath: "reset/send")
}

private let emailKey = "email"
private let passwordKey = "password"
private let tokenKey = "token"
private let tokenIdKey = "tokenId"

open class CoreUserPasswordAuthProviderClient: CoreAuthProviderClient {
    private let routes: Routes

    public init(withProviderName providerName: String = "local-userpass",
                withRequestClient requestClient: StitchRequestClient,
                withRoutes routes: StitchAuthRoutes) {
        self.routes = Routes.init(withAuthRoutes: routes,
                                  withProviderName: providerName)
        super.init(withProviderName: providerName,
                   withRequestClient: requestClient,
                   withAuthRoutes: routes)

    }

    public func credential(forUsername username: String,
                           forPassword password: String) -> UserPasswordCredential {
        return UserPasswordCredential.init(withUsername: username, withPassword: password)
    }

    public func register(withEmail email: String,
                         withPassword password: String) throws -> Response {
        return try self.requestClient.doJSONRequestRaw(StitchDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [emailKey: email,
                           passwordKey: password]
            $0.path = self.routes.registerWithEmailRoute
        }.build())
    }

    public func confirmUser(withToken token: String,
                            withTokenId tokenId: String) throws -> Response {
        return try self.requestClient.doJSONRequestRaw(StitchDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [tokenKey: token,
                           tokenIdKey: tokenId]
            $0.path = self.routes.resendConfirmationEmailRoute
        }.build())
    }

    public func resendConfirmation(toEmail email: String) throws -> Response {
        return try self.requestClient.doJSONRequestRaw(StitchDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [emailKey: email]
            $0.path = self.routes.resendConfirmationEmailRoute
        }.build())
    }

    public func reset(password: String,
                      withToken token: String,
                      withTokenId tokenId: String) throws -> Response {
        return try self.requestClient.doJSONRequestRaw(StitchDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [tokenKey: token,
                           tokenIdKey: tokenId,
                           passwordKey: password]
            $0.path = self.routes.resetPasswordRoute
        }.build())
    }

    public func sendResetPasswordEmail(toEmail email: String) throws -> Response {
        return try self.requestClient.doJSONRequestRaw(StitchDocRequestBuilderImpl {
            $0.method = .post
            $0.document = [emailKey: email]
            $0.path = self.routes.sendResetPasswordEmailRoute
        }.build())
    }
}
