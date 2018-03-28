public struct APIStitchUserIdentity: StitchUserIdentity, Hashable {
    public var hashValue: Int {
        return self.id.hashValue
    }

    public static func == (lhs: APIStitchUserIdentity, rhs: APIStitchUserIdentity) -> Bool {
        return lhs.id == rhs.id
    }

    public var id: String

    public var providerType: String

    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case providerType = "provider_type"
    }
}
