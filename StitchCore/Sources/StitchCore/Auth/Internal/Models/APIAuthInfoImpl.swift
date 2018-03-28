import Foundation

public struct APIAuthInfoImpl: APIAuthInfo {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    public let userId: String

    public let deviceId: String

    public let accessToken: String

    public let refreshToken: String
}

public struct ExtendedAuthInfoImpl: ExtendedAuthInfo {
    public let loggedInProviderType: String

    public let loggedInProviderName: String

    public let userProfile: StitchUserProfile
}
