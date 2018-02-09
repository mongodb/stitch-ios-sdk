import Foundation
@testable import StitchCore

/// Creates a new user for an application
internal struct UserCreator: Encodable {
    /// email for the new user
    let email: String
    /// password for the new user
    let password: String
}

/// View of a User of an application
struct UserView: Decodable {
    /// id of the user
    var id: String?
}

extension AppsResource.AppResource.UsersResource {
    /// GET a user of an application
    /// - parameter uid: id of the user
    func user(uid: String) -> UserResource {
        return UserResource.init(httpClient: self.httpClient,
                                 url: "\(url)/\(uid)")
    }
}
