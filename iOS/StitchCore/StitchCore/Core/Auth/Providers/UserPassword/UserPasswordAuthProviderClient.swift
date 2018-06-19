import Foundation
import StitchCoreSDK

/**
 * :nodoc:
 * A factory for a `UserPasswordAuthProviderClient`.
 */
public final class UserPasswordClientFactory: AuthProviderClientFactory {
    public typealias Client = UserPasswordAuthProviderClient

    public func client(withRequestClient requestClient: StitchRequestClient,
                       withRoutes routes: StitchAuthRoutes,
                       withDispatcher dispatcher: OperationDispatcher) -> UserPasswordAuthProviderClient {
        return UserPasswordAuthProviderClientImpl.init(withRequestClient: requestClient,
                                                       withAuthRoutes: routes,
                                                       withDispatcher: dispatcher)
    }
}

/**
 * Global factory const which can be used to create a `UserPasswordAuthProviderClient` with a `StitchAuth`. Pass this
 * into `StitchAuth.providerClient(fromFactory:) to get a `UserPasswordAuthProviderClient`.
 */
public let userPasswordClientFactory = UserPasswordClientFactory()

/**
 * A protocol defining methods for interacting with username/password authentication provider in Stitch.
 */
public protocol UserPasswordAuthProviderClient {
    // swiftlint:disable line_length

    /**
     * Registers a new email identity with the username/password provider, and sends a confirmation email to the
     * provided address.
     *
     * - parameters:
     *     - withEmail: The email address of the user to register.
     *     - withPassword: The password that the user created for the new username/password identity.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func register(withEmail email: String, withPassword password: String, completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Confirms an email identity with the username/password provider.
     *
     * - parameters:
     *     - withToken: The confirmation token that was emailed to the user.
     *     - withTokenID: The confirmation token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func confirmUser(withToken token: String, withTokenID tokenID: String, completionHandler: @escaping (StitchResult<Void>) -> Void)

    // swiftlint:enable line_length

    /**
     * Re-sends a confirmation email to a user that has registered but not yet confirmed their email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to re-send a confirmation for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func resendConfirmation(toEmail email: String, completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Sends a password reset email to the given email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to send a password reset email for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func sendResetPasswordEmail(toEmail email: String, completionHandler: @escaping (StitchResult<Void>) -> Void)

    // swiftlint:disable line_length

    /**
     * Resets the password of an email identity using the password reset token emailed to a user.
     *
     * - parameters:
     *     - password: The desired new password.
     *     - withToken: The password reset token that was emailed to the user.
     *     - withTokenID: The password reset token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func reset(password: String, withToken token: String, withTokenID tokenID: String, completionHandler: @escaping (StitchResult<Void>) -> Void)

    // swiftlint:enable line_length
}

private class UserPasswordAuthProviderClientImpl: CoreUserPasswordAuthProviderClient, UserPasswordAuthProviderClient {
    private let dispatcher: OperationDispatcher

    init(withRequestClient requestClient: StitchRequestClient,
         withAuthRoutes authRoutes: StitchAuthRoutes,
         withDispatcher dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(withRequestClient: requestClient, withAuthRoutes: authRoutes)
    }

    func register(withEmail email: String,
                  withPassword password: String,
                  completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.register(withEmail: email, withPassword: password)
        }
    }

    func confirmUser(withToken token: String,
                     withTokenID tokenID: String,
                     completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.confirmUser(withToken: token, withTokenID: tokenID)
        }
    }

    func resendConfirmation(toEmail email: String, completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.resendConfirmation(toEmail: email)
        }
    }

    func reset(password: String,
               withToken token: String,
               withTokenID tokenID: String,
               completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.reset(password: password, withToken: token, withTokenID: tokenID)
        }
    }

    func sendResetPasswordEmail(toEmail email: String, completionHandler: @escaping (StitchResult<Void>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            _ = try super.sendResetPasswordEmail(toEmail: email)
        }
    }
}
