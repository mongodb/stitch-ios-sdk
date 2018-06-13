import Foundation

/// View into a specific auth provider
public struct AuthProviderResponse: Codable {
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
        self.disabled = try container.decode(Bool.self, forKey: .disabled)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
    }
}

extension Apps.App.AuthProviders {
    /// GET an auth provider
    /// - parameter providerID: id of the provider
    public func authProvider(providerID: String) -> Apps.App.AuthProviders.AuthProvider {
        return Apps.App.AuthProviders
            .AuthProvider.init(adminAuth: self.adminAuth,
                               url: "\(url)/\(providerID)")
    }
}
