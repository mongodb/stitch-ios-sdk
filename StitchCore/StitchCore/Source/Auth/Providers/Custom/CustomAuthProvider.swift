import Foundation
import ExtendedJson

// CustomAuthProvider is a special case that does not
// follow previous protocols.
public struct CustomAuthProvider: AuthProvider {
    public var type: String = AuthProviderTypes.custom.rawValue

    public var payload: Document { return ["token": jwt] }

    public let jwt: String

    public init(jwt: String) {
        self.jwt = jwt
    }
}
