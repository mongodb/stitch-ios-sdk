import Foundation
import PromiseKit
@testable import StitchCore

/// View into a specific application
struct AppResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case name, id = "_id", clientAppId = "client_app_id"
    }

    /// unique, internal id of this application
    let id: String
    /// name of this application
    let name: String
    /// public, client app id (for `StitchClient`) of this application
    let clientAppId: String
}

extension Apps {
    /// POST a new application
    /// - parameter name: name of the new application
    /// - parameter defaults: whether or not to enable default values
    func create(name: String, defaults: Bool = false) -> Promise<AppResponse> {
        return httpClient.doRequest {
            $0.endpoint = "\(self.url)?defaults=\(defaults)"
            $0.method = .post
            try $0.encode(withData: ["name": name])
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }

    /// GET an application
    /// - parameter id: id for the application
    func app(withAppId appId: String) -> App {
        return App.init(httpClient: self.httpClient, url: "\(url)/\(appId)")
    }
}
