import XCTest
import Foundation
@testable import StitchCore

class JWTTests: XCTestCase {
    struct JWTTestPayload: Codable {
        let sub: String
        let name: String
        let admin: Bool
    }

    func testJwt() throws {
        let headers = try JSONEncoder().encode([
            "alg": "HS256",
            "typ": "JWT"
        ]).base64URLEncodedString()

        XCTAssertEqual("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9", headers)

        let payload = try JSONEncoder().encode(
            JWTTestPayload(sub: "1234567890", name: "John Doe", admin: true)
        ).base64URLEncodedString()

        XCTAssertEqual("eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9", payload)

        let sig = try Hmac.sha256(
            data: headers + "." + payload,
            key: "secret"
        ).digest()

        XCTAssertEqual("TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ", sig.base64URLEncodedString())
    }
}
