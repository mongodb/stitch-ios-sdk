import Foundation
import ExtendedJson
/// AnonymousAuthProvider provides a way to authenticate anonymously.
public struct AnonymousAuthProvider: AuthProvider {
    /// The authentication type for anonymous login.
    public let type: String = "anon-user"
    
    /// The JSON payload containing authentication material.
    public var payload: Document = [:]
}
