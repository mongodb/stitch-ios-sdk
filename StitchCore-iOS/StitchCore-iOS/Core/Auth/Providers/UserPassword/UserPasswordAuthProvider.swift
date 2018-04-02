import Foundation
import StitchCore

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a
 * `UserPasswordAuthProviderClient`.
 */
public final class UserPasswordAuthProvider {
    /**
     * An `AuthProviderClientSupplier` which can be used with `StitchAuth` to retrieve a
     * `UserPasswordAuthProviderClient`.
     */
    public static let clientSupplier: ClientSupplierImpl = ClientSupplierImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientSupplier` that produces a `UserPasswordAuthProviderClient`.
     */
    public final class ClientSupplierImpl: AuthProviderClientSupplier {
        public typealias Client = UserPasswordAuthProviderClient

        public func client(withRequestClient requestClient: StitchRequestClient,
                           withRoutes routes: StitchAuthRoutes,
                           withDispatcher dispatcher: OperationDispatcher) -> UserPasswordAuthProviderClient {
            return UserPasswordAuthProviderClientImpl.init(withRequestClient: requestClient,
                                                           withRoutes: routes,
                                                           withDispatcher: dispatcher)
        }
    }
}

/**
 * A protocol that provides a method for getting a `StitchCredential` property
 * that can be used to log in with the Username/Password authentication provider.
 */
public protocol UserPasswordAuthProviderClient {
    /**
     * Gets a credential that can be used to log in with the Username/Password authentication provider.
     *
     * - parameters:
     *     - forUserName: The username to authenticate as. This is usually the email address of the user.
     *     - forPassword: The password of the user.
     * - returns: a credential conforming to `StitchCredential`
     */
    func credential(forUsername username: String, forPassword password: String) -> UserPasswordCredential

    /**
     * Registers a new email identity with the username/password provider, and sends a confirmation email to the
     * provided address.
     *
     * - parameters:
     *     - withEmail: The email address of the user to register.
     *     - withPassword: The password that the user created for the new username/password identity.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func register(withEmail email: String, withPassword password: String, completionHandler: @escaping (Error?) -> Void)

    // swiftlint:disable line_length

    /**
     * Confirms an email identity with the username/password provider.
     *
     * - parameters:
     *     - withToken: The confirmation token that was emailed to the user.
     *     - withTokenId: The confirmation token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func confirmUser(withToken token: String, withTokenId tokenId: String, completionHandler: @escaping (Error?) -> Void)

    // swiftlint:enable line_length

    /**
     * Re-sends a confirmation email to a user that has registered but not yet confirmed their email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to re-send a confirmation for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func resendConfirmation(toEmail email: String, completionHandler: @escaping (Error?) -> Void)

    /**
     * Sends a password reset email to the given email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to send a password reset email for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func sendResetPasswordEmail(toEmail email: String, completionHandler: @escaping (Error?) -> Void)

    // swiftlint:disable line_length

    /**
     * Resets the password of an email identity using the password reset token emailed to a user.
     *
     * - parameters:
     *     - password: The desired new password.
     *     - withToken: The password reset token that was emailed to the user.
     *     - withTokenId: The password reset token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func reset(password: String, withToken token: String, withTokenId tokenId: String, completionHandler: @escaping (Error?) -> Void)

    // swiftlint:enable line_length
}

private class UserPasswordAuthProviderClientImpl: CoreUserPasswordAuthProviderClient, UserPasswordAuthProviderClient {
    private let dispatcher: OperationDispatcher

    init(withRequestClient requestClient: StitchRequestClient,
         withRoutes routes: StitchAuthRoutes,
         withDispatcher dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(withRequestClient: requestClient, withRoutes: routes)
    }

    func register(withEmail email: String,
                  withPassword password: String,
                  completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.register(withEmail: email, withPassword: password)
        }
    }

    func confirmUser(withToken token: String,
                     withTokenId tokenId: String,
                     completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.confirmUser(withToken: token, withTokenId: tokenId)
        }
    }

    func resendConfirmation(toEmail email: String, completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.resendConfirmation(toEmail: email)
        }
    }

    func reset(password: String,
               withToken token: String,
               withTokenId tokenId: String,
               completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.reset(password: password, withToken: token, withTokenId: tokenId)
        }
    }

    func sendResetPasswordEmail(toEmail email: String, completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.sendResetPasswordEmail(toEmail: email)
        }
    }
}
