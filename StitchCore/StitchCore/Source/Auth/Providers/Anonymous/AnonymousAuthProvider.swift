import Foundation

/// AnonymousAuthProvider provides a way to authenticate anonymously.
public struct AnonymousAuthProvider: AuthProvider {
    /// The authentication type for anonymous login.
    public let type: String = "anon"

    /// The name for anonymous login
    public let name: String = "user"

    /// The JSON payload containing authentication material.
    public var payload: [String: Any] = [:]
}
