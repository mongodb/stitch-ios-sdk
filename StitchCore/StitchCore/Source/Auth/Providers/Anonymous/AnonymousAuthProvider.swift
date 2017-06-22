import Foundation

/// AnonymousAuthProvider provides a way to authenticate anonymously.
public struct AnonymousAuthProvider: AuthProvider {
    /// The authentication type for anonymous login.
    public var type: String {
        return "anon"
    }
    /// The name for anonymous login
    public var name: String {
        return "user"
    }
    /// The JSON payload containing authentication material.
    public var payload: [String : Any] {
        return [:]
    }
}
