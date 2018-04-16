import Foundation
import StitchCore_iOS
import PromiseKit

extension UserPasswordAuthProviderClient {
    /**
     * Registers a new email identity with the username/password provider, and sends a confirmation email to the
     * provided address.
     *
     * - parameters:
     *     - withEmail: The email address of the user to register.
     *     - withPassword: The password that the user created for the new username/password identity.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func register(withEmail email: String, withPassword password: String) -> Promise<Void> {
        return Promise {
            self.register(withEmail: email,
                          withPassword: password,
                          completionHandler: adapter($0))
        }
    }

    /**
     * Confirms an email identity with the username/password provider.
     *
     * - parameters:
     *     - withToken: The confirmation token that was emailed to the user.
     *     - withTokenId: The confirmation token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func confirmUser(withToken token: String, withTokenId tokenId: String) -> Promise<Void> {
        return Promise {
            self.confirmUser(withToken: token,
                             withTokenId: tokenId,
                             completionHandler: adapter($0))
        }
    }

    // swiftlint:enable line_length

    /**
     * Re-sends a confirmation email to a user that has registered but not yet confirmed their email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to re-send a confirmation for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func resendConfirmation(toEmail email: String) -> Promise<Void> {
        return Promise {
            self.resendConfirmation(toEmail: email,
                                    completionHandler: adapter($0))
        }
    }

    /**
     * Sends a password reset email to the given email address.
     *
     * - parameters:
     *     - toEmail: The email address of the user to send a password reset email for.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func sendResetPasswordEmail(toEmail email: String) -> Promise<Void> {
        return Promise {
            return self.sendResetPasswordEmail(toEmail: email,
                                               completionHandler: adapter($0))
        }
    }

    /**
     * Resets the password of an email identity using the password reset token emailed to a user.
     *
     * - parameters:
     *     - password: The desired new password.
     *     - withToken: The password reset token that was emailed to the user.
     *     - withTokenId: The password reset token id that was emailed to the user.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func reset(password: String, withToken token: String, withTokenId tokenId: String) -> Promise<Void> {
        return Promise {
            return self.reset(password: password,
                              withToken: token,
                              withTokenId: token,
                              completionHandler: adapter($0))
        }
    }
}
