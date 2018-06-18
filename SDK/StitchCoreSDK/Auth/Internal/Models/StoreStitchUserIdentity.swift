import Foundation

/**
 * A struct describing the structure of how user identity information is stored in persisted `Storage`.
 */
internal struct StoreStitchUserIdentity: Codable, StitchUserIdentity {

    /**
     * The id of this identity in MongoDB Stitch
     *
     * - important: This is **not** the id of the Stitch user.
     */
    let id: String

    /**
     * A string indicating the authentication provider that provides this identity.
     */
    let providerType: String

    /**
     * Initializes the `StoreStitchUserIdentity` from a plain `StitchUserIdentity.
     */
    init(withIdentity identity: StitchUserIdentity) {
        self.id = identity.id
        self.providerType = identity.providerType
    }
}
