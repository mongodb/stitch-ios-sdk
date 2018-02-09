import Foundation
@testable import StitchCore

/// View into a specific Service
internal struct ServiceView: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id", name, type
    }

    /// id of this service
    let id: String
    /// name of this service
    let name: String
    /// the type of service
    let type: String
}

extension AppsResource.AppResource.ServicesResource {
    /// GET a service
    /// - parameter id: id of the requested service
    func service(withId id: String) -> ServiceResource {
        return ServiceResource.init(httpClient: self.httpClient,
                                     url: "\(self.url)/\(id)")
    }
}
