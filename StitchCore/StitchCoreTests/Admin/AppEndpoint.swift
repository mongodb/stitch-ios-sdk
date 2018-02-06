import Foundation
import PromiseKit
@testable import StitchCore

struct AppView: Codable {
    enum CodingKeys: String, CodingKey {
        case name, id = "_id", clientAppId = "client_app_id"
    }

    let id: String
    let name: String
    let clientAppId: String
}

public final class AppEndpoint: Endpoint, Get, Remove {
    typealias Model = AppView

    internal let httpClient: StitchHTTPClient
    internal let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     appUrl: String) {
        self.httpClient = httpClient
        self.url = appUrl
    }

    lazy var authProviders: AuthProvidersEndpoint =
        AuthProvidersEndpoint.init(httpClient: self.httpClient,
                                   authProvidersUrl: "\(self.url)/auth_providers")

    lazy var users: UsersEndpoint =
        UsersEndpoint.init(httpClient: self.httpClient,
                           usersUrl: "\(self.url)/users")

    lazy var userRegistrations: UserRegistrationsEndpoint =
        UserRegistrationsEndpoint.init(httpClient: self.httpClient,
                                       userRegistrationsUrl: "\(self.url)/user_registrations")

    lazy var services: ServicesEndpoint =
        ServicesEndpoint.init(httpClient: self.httpClient, servicesUrl: "\(self.url)/services")
}

public final class AppsEndpoint: Endpoint, List {
    typealias Model = AppView

    let httpClient: StitchHTTPClient
    let url: String

    internal init(httpClient: StitchHTTPClient,
                  groupUrl: String) {
        self.httpClient = httpClient
        self.url = groupUrl
    }

    func create(name: String, defaults: Bool = false) -> Promise<AppView> {
        return httpClient.doRequest {
            $0.endpoint = "\(self.url)?defaults=\(defaults)"
            $0.method = .post
            try $0.encode(withData: ["name": name])
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }

    func app(withAppId appId: String) -> AppEndpoint {
        return AppEndpoint.init(httpClient: self.httpClient, appUrl: "\(url)/\(appId)")
    }
}
