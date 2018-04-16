import Foundation
import StitchCore_iOS
import StitchCore
import PromiseKit

extension StitchAuth {
    /**
     * Authenticates the client as a MongoDB Stitch user using the provided `StitchCredential`.
     *
     * - parameters:
     *     - withCredential: The `StitchCore.StitchCredential` used to authenticate the
     *                       client. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `providerClient` method.
     *     - completionHandler: The completion handler to call when the login is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - user: A `StitchUser` object representing the user that the client is now authenticated as, or `nil` if the
     *             login failed.
     *     - error: An error object that indicates why the login failed, or `nil` if the login was successful.
     */
    func login(withCredential credential: StitchCredential) -> Promise<StitchUser> {
        return Promise {
            self.login(withCredential: credential, adapter($0))
        }
    }

    // swiftlint:enable line_length

    /**
     * Logs out the currently authenticated user, and clears any persisted
     * authentication information.
     *
     * - parameters:
     *     - completionHandler: The completion handler to call when the logout is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - error: Will always be nil, since the underlying implementation squashes errors and always clears local
     *              authentication information.
     */
    func logout() -> Promise<Void> {
        return Promise {
            self.logout(adapter($0))
        }
    }
}
