import Foundation

/// View into a specific Service
public struct ServiceResponse: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id", name, type
    }

    /// id of this service
    public let id: String
    /// name of this service
    public let name: String
    /// the type of service
    public let type: String
}

extension Apps.App.Services {
    /// GET a service
    /// - parameter id: id of the requested service
    public func service(withId id: String) -> Service {
        return Service.init(adminAuth: self.adminAuth,
                            url: "\(self.url)/\(id)")
    }
}
