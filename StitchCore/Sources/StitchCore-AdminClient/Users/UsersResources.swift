import Foundation

/// Creates a new user for an application
public struct UserCreator: Encodable {
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
    
    /// email for the new user
    let email: String
    /// password for the new user
    let password: String
}

/// View of a User of an application
public struct UserResponse: Decodable {
    /// id of the user
    var id: String?
}

extension Apps.App.Users {
    /// GET a user of an application
    /// - parameter uid: id of the user
    public func user(uid: String) -> User {
        return User.init(adminAuth: adminAuth,
                         url: "\(url)/\(uid)")
    }
}
