import Foundation
/**
 * A struct containing all information necessary to represent a user's authentication state with respect to Stitch.
 */
internal struct AuthStateHolder {
    /**
     * The actual AuthInfo that is held by this struct
     */
    var authInfo: AuthInfo?

    /**
     * A function to clear the authentication state.
     *
     * - important: Does not clear authentication state from underlying storage.
     */
    mutating func clearState() {
        self.authInfo = authInfo?.emptiedOut
    }
}
