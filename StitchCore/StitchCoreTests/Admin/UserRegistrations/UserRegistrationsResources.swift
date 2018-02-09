import Foundation
import PromiseKit
@testable import StitchCore

/// Struct that allows the retrieval of the token
/// and tokenId of a confirmation email, for the sake
/// of skirting email registration
public struct ConfirmationEmail: Codable {
    private enum CodingKeys: String, CodingKey {
        case token, tokenId = "token_id"
    }

    /// registration token
    let token: String
    /// registration token id
    let tokenId: String
}

extension AppsResource.AppResource.UserRegistrationsResource {
    /// GET confirmation email token and tokenId
    /// - parameter email: email that the confirmation email was sent to
    func sendConfirmation(toEmail email: String) -> Promise<ConfirmationEmail> {
        return self.httpClient.doRequest { request in
            request.endpoint = "\(self.url)/by_email/\(email)/send_confirm"
            request.method = .post
        }.flatMap {
            return try JSONDecoder().decode(ConfirmationEmail.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
