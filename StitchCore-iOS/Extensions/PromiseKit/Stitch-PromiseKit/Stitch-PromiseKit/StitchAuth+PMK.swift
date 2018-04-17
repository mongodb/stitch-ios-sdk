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
     * - returns: A `Promise` resolved when the login is complete.
     *            This handler is executed on a non-main global `DispatchQueue`.
     *            If resolved, a `StitchUser` object representing the user that the client is now authenticated as, or `nil` if the
     *             login failed.
     */
    func login(withCredential credential: StitchCredential) -> Promise<StitchUser> {
        return Promise {
            self.login(withCredential: credential, adapter($0))
        }
    }

    /**
     * Logs out the currently authenticated user, and clears any persisted
     * authentication information.
     *
     * - returns: A `Promise` that will be rejected if the call fails.
     */
    func logout() -> Promise<Void> {
        return Promise {
            self.logout(adapter($0))
        }
    }
}
