import StitchCore_iOS
import StitchCore
import PromiseKit

extension StitchUser {
    /**
     * Links this `StitchUser` with a new identity, where the identity is defined by the credential specified as a
     * parameter. This will only be successful if this `StitchUser` is the currently authenticated `StitchUser` for the
     * client from which it was created.
     *
     * - parameters:
     *     - withCredential: The `StitchCore.StitchCredential` used to link the user to a new
     *                       identity. Credentials can be retrieved from an
     *                       authentication provider client, which is retrieved
     *                       using the `getProviderClient` method on `StitchAuth`.
     *     - completionHandler: The completion handler to call when the linking is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - user: The current user, or `nil` if the link failed.
     *     - error: An error object that indicates why the link failed, or `nil` if the link was successful.
     */
    func link(withCredential credential: StitchCredential) -> Promise<StitchUser> {
        return Promise { self.link(withCredential: credential, adapter($0)) }
    }
}
