import Foundation

internal struct APIAccessToken: Decodable {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }

    public let accessToken: String
}
