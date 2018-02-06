import Foundation
import PromiseKit
@testable import StitchCore

public struct ConfirmationEmail: Codable {
    private enum CodingKeys: String, CodingKey {
        case token, tokenId = "token_id"
    }
    
    let token: String
    let tokenId: String
}

public final class UserRegistrationsEndpoint: Endpoint {
    internal let httpClient: StitchHTTPClient
    internal let url: String

    internal init(httpClient: StitchHTTPClient,
                  userRegistrationsUrl: String) {
        self.httpClient = httpClient
        self.url = userRegistrationsUrl
    }

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
