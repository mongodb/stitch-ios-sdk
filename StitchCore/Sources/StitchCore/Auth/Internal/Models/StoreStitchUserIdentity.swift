import Foundation

internal struct StoreStitchUserIdentity: Codable, StitchUserIdentity {
    let id: String
    let providerType: String

    init(withIdentity identity: StitchUserIdentity) {
        self.id = identity.id
        self.providerType = identity.providerType
    }
}
