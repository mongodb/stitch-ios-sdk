import Foundation
@testable import StitchCore

/// View into a specific auth provider
internal struct AuthProviderView: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id", disabled, name, type
    }

    /// unique id of this provider
    public let id: String
    /// whether or not this provider is disabled
    public let disabled: Bool
    /// name of this provider
    public let name: String
    /// the type of this provider
    public let type: String

    public init(from decoder: Decoder) throws {
        // decode from a container. as opposed to
        // allowing this to happen magically, we
        // need to coerce the `disabled` `Int` to
        // a `Bool` for legibility
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.disabled = try container.decode(Int.self, forKey: .disabled) == 0 ? false : true
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
    }
}

extension AppsResource.AppResource.AuthProvidersResource {
    /// GET an auth provider
    /// - parameter providerId: id of the provider
    func authProvider(providerId: String) -> AppsResource.AppResource.AuthProvidersResource.AuthProviderResource {
        return AppsResource.AppResource.AuthProvidersResource
            .AuthProviderResource.init(httpClient: self.httpClient,
                                       url: "\(url)/\(providerId)")
    }
}
