public protocol CoreStitchUser {
    var id: String { get }
    var loggedInProviderType: String { get }
    var loggedInProviderName: String { get }
    var userType: String { get }
    var profile: StitchUserProfile { get }
    var identities: [StitchUserIdentity] { get }
}

public func ==(_ lhs: CoreStitchUser,
               _ rhs: CoreStitchUser) -> Bool {
    return lhs.id == rhs.id
}
