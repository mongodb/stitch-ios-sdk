import Foundation
import StitchCore

/// Struct that allows the retrieval of the token
/// and tokenID of a confirmation email, for the sake
/// of skirting email registration
public struct ConfirmationEmail: Codable {
    private enum CodingKeys: String, CodingKey {
        case token, tokenID = "token_id"
    }

    /// registration token
    public let token: String
    /// registration token id
    public let tokenID: String
}

extension Apps.App.UserRegistrations {
    /// GET confirmation email token and tokenID
    /// - parameter email: email that the confirmation email was sent to
    public func sendConfirmation(toEmail email: String) throws -> ConfirmationEmail {
        let req = try StitchAuthRequestBuilder()
            .with(method: .post)
            .with(path: "\(self.url)/by_email/\(email)/send_confirm")
            .build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(ConfirmationEmail.self, from: response.body!)
    }
}
