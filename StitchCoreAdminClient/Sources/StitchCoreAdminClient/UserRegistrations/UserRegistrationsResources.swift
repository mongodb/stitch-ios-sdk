import Foundation
import StitchCore

/// Struct that allows the retrieval of the token
/// and tokenId of a confirmation email, for the sake
/// of skirting email registration
public struct ConfirmationEmail: Codable {
    private enum CodingKeys: String, CodingKey {
        case token, tokenId = "token_id"
    }

    /// registration token
    public let token: String
    /// registration token id
    public let tokenId: String
}

extension Apps.App.UserRegistrations {
    /// GET confirmation email token and tokenId
    /// - parameter email: email that the confirmation email was sent to
    public func sendConfirmation(toEmail email: String) throws -> ConfirmationEmail {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.post
            $0.path = "\(self.url)/by_email/\(email)/send_confirm"
        }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(ConfirmationEmail.self, from: response.body!)
    }
}
