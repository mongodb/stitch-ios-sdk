/**
 * A class representing the routes on the Stitch server to perform various actions related to the username/password
 * authentication provider.
 */
private final class Routes {
    /**
     * The authentication API route that forms the base of these provider routes.
     */
    private let baseRoute: String

    /**
     * Initializes the routes with a `StitchAuthRoutes` and the name of the provider.
     */
    fileprivate init(withBaseRoute baseRoute: String,
                     withProviderName providerName: String) {
        self.baseRoute = baseRoute
    }

    /**
     * Private helper which returns the provided path, appended to the base route for the authentication provider.
     */
    private func extensionRoute(forPath path: String) -> String {
        return "\(baseRoute)/\(path)"
    }

    /**
     * The route for registering a new user's email address.
     */
    fileprivate lazy var registerWithEmailRoute = self.extensionRoute(forPath: "register")

    /**
     * The route for confirming a new user's email address.
     */
    fileprivate lazy var confirmUserRoute = self.extensionRoute(forPath: "confirm")

    /**
     * The route for re-sending a new user's confirmation email.
     */
    fileprivate lazy var resendConfirmationEmailRoute = self.extensionRoute(forPath: "confirm/send")

    /**
     * The route for resetting an existing user's password.
     */
    fileprivate lazy var resetPasswordRoute = self.extensionRoute(forPath: "reset")

    /**
     * The route for sending a password reset email to an existing user.
     */
    fileprivate lazy var sendResetPasswordEmailRoute = self.extensionRoute(forPath: "reset/send")
}

private let emailKey = "email"
private let passwordKey = "password"
private let tokenKey = "token"
private let tokenIDKey = "tokenId"

/**
 * :nodoc:
 * A client for the username/password authentication provider which can be used to obtain a credential for logging in,
 * and to perform requests specifically related to the username/password provider.
 */
open class CoreUserPasswordAuthProviderClient: CoreAuthProviderClient<StitchRequestClient> {
    /**
     * The routes on the Stitch server to perform the actions made available by this provider client.
     */
    private let routes: Routes

    /**
     * Initializes this provider client with the name of the provider, the request client used to make requests, and
     * authentication routes to which the requests will be made.
     */
    public init(withProviderName providerName: String = "local-userpass",
                withRequestClient requestClient: StitchRequestClient,
                withAuthRoutes authRoutes: StitchAuthRoutes) {
        let baseRoute = authRoutes.authProviderRoute(withProviderName: providerName)

        self.routes = Routes.init(withBaseRoute: baseRoute,
                                  withProviderName: providerName)
        super.init(withProviderName: providerName,
                   withRequestClient: requestClient,
                   withBaseRoute: baseRoute)

    }

    /**
     * Registers a new email identity with the username/password provider, and sends a confirmation email to the
     * provided address. Blocks the current thread until the request is completed.
     *
     * - parameters:
     *     - withEmail: The email address of the user to register.
     *     - withPassword: The password that the user created for the new username/password identity.
     */
    public func register(withEmail email: String,
                         withPassword password: String) throws -> Response {
        return try self.requestClient.doRequest(
            StitchDocRequestBuilder()
                .with(method: .post)
                .with(document: [emailKey: email,
                                 passwordKey: password])
                .with(path: self.routes.registerWithEmailRoute)
                .build()
        )
    }

    /**
     * Confirms an email identity with the username/password provider. Blocks the current thread until the request
     * is completed.
     *
     * - parameters:
     *     - withToken: The confirmation token that was emailed to the user.
     *     - withTokenID: The confirmation token id that was emailed to the user.
     */
    public func confirmUser(withToken token: String,
                            withTokenID tokenID: String) throws -> Response {
        return try self.requestClient.doRequest(
            StitchDocRequestBuilder()
                .with(method: .post)
                .with(document: [tokenKey: token,
                                 tokenIDKey: tokenID])
                .with(path: self.routes.confirmUserRoute)
                .build()
        )
    }

    /**
     * Re-sends a confirmation email to a user that has registered but not yet confirmed their email address. Blocks
     * the current thread until the request is completed.
     *
     * - parameters:
     *     - toEmail: The email address of the user to re-send a confirmation for.
     */
    public func resendConfirmation(toEmail email: String) throws -> Response {
        
        return try self.requestClient.doRequest(
            StitchDocRequestBuilder()
                .with(method: .post)
                .with(document: [emailKey: email])
                .with(path: self.routes.resendConfirmationEmailRoute)
                .build()
        )
    }

    /**
     * Sends a password reset email to the given email address. Blocks the current thread until the request is
     * completed.
     *
     * - parameters:
     *     - toEmail: The email address of the user to send a password reset email for.
     */
    public func sendResetPasswordEmail(toEmail email: String) throws -> Response {
        return try self.requestClient.doRequest(
            StitchDocRequestBuilder()
                .with(method: .post)
                .with(document: [emailKey: email])
                .with(path: self.routes.sendResetPasswordEmailRoute)
                .build()
        )
    }

    /**
     * Resets the password of an email identity using the password reset token emailed to a user. Blocks the current
     * thread until the request is completed.
     *
     * - parameters:
     *     - password: The desired new password.
     *     - withToken: The password reset token that was emailed to the user.
     *     - withTokenID: The password reset token id that was emailed to the user.
     */
    public func reset(password: String,
                      withToken token: String,
                      withTokenID tokenID: String) throws -> Response {
        return try self.requestClient.doRequest(
            StitchDocRequestBuilder()
                .with(method: .post)
                .with(document: [tokenKey: token,
                                 tokenIDKey: tokenID,
                                 passwordKey: password])
                .with(path: self.routes.resetPasswordRoute)
                .build()
        )
    }
}
