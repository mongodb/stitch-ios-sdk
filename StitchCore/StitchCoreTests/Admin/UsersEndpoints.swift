import Foundation
@testable import StitchCore

struct UserCreator: Encodable {
    let email: String
    let password: String
}
struct UserView: Decodable {
    var id: String?
}

public final class UserEndpoint: Endpoint, Get, Remove {
    typealias Model = UserView

    internal let httpClient: StitchHTTPClient
    internal let url: String

    internal init(httpClient: StitchHTTPClient,
                  userUrl: String) {
        self.httpClient = httpClient
        self.url = userUrl
    }
}

public final class UsersEndpoint: Endpoint, List, Create {
    typealias Model = UserView
    typealias CreatorModel = UserCreator

    internal let httpClient: StitchHTTPClient
    internal let url: String

    internal init(httpClient: StitchHTTPClient,
                  usersUrl: String) {
        self.httpClient = httpClient
        self.url = usersUrl
    }

    func user(uid: String) -> UserEndpoint {
        return UserEndpoint.init(httpClient: self.httpClient,
                                 userUrl: "\(url)/\(uid)")
    }
}
