import XCTest
import Foundation
import StitchLogger
import ExtendedJson
@testable import StitchCore

class AuthTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LogManager.minimumLogLevel = .debug
    }

    override func tearDown() {
        super.tearDown()
    }

    let stitchClient = StitchClient(appId: "test-uybga")

    func testFetchAuthProviders() throws {
        let exp = expectation(description: "fetched auth providers")
        stitchClient.fetchAuthProviders().then { (authInfo: AuthProviderInfo) in
            let anon = authInfo.anonymousAuthProviderInfo
            XCTAssertNotNil(anon)
            XCTAssertEqual(anon?.name, "anon-user")
            XCTAssertEqual(anon?.type, "anon-user")
            XCTAssertNotNil(authInfo.emailPasswordAuthProviderInfo)
            XCTAssertNotNil(authInfo.googleProviderInfo)
            XCTAssertNil(authInfo.facebookProviderInfo)
            XCTAssert(authInfo.googleProviderInfo?.config.clientId ==
                "405021717222-8n19u6ij79kheu4lsaeekfh9b1dng7b7.apps.googleusercontent.com")
            XCTAssert(authInfo.googleProviderInfo?.metadataFields?.contains {$0.name == "profile"} ?? false)
            XCTAssert(authInfo.googleProviderInfo?.metadataFields?.contains {$0.name == "email"} ?? false)
            XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.config.emailConfirmationUrl,
                           "http://confirmation.com")
            XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.config.resetPasswordUrl, "http://confirmation.com")
            XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.name, "local-userpass")
            XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.type, "local-userpass")

            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
        }

        wait(for: [exp], timeout: 10)
    }

    func testLogin() throws {
        let exp = expectation(description: "logged in")
        stitchClient.login(withProvider: AnonymousAuthProvider()).then { (userId: String) in
            print(userId)
            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
        }
        wait(for: [exp], timeout: 10)
    }

    func testUserProfile() throws {
        let exp = expectation(description: "user profile matched")
        stitchClient.login(withProvider: AnonymousAuthProvider()).then { (_: String)-> StitchTask<UserProfile> in
            return (self.stitchClient.auth?.fetchUserProfile())!
        }.then { (userProfile: UserProfile) in
            XCTAssertEqual("normal", userProfile.type)
            XCTAssertEqual("anon-user", userProfile.identities[0].providerType)
            print(userProfile)
            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
        }

        wait(for: [exp], timeout: 30)
    }

    private struct DummyCustomPayload: Codable {
        //swiftlint:disable:next nesting
        struct Metadata: Codable {
            let email = "name@example.com"
            let name = "Joe Bloggs"
            let picture = "https://goo.gl/xqR6Jd"
        }

        let aud = "test-jsf-fpleb"
        let sub = "uniqueUserID"
        let exp = UInt(Date().addingTimeInterval(5 * 60.0).timeIntervalSince1970)
        let iat = UInt(Date().timeIntervalSince1970)
        let nbf = UInt(Date().timeIntervalSince1970)
        //swiftlint:disable:next identifier_name
        let stitch_meta: Metadata = Metadata()
    }

    func testCustomLogin() throws {
        let exp = expectation(description: "logged in")

        let headers = try JSONEncoder().encode([
            "alg": "HS256",
            "typ": "JWT"
        ]).base64URLEncodedString()

        let dummyPayload = DummyCustomPayload()
        let payload = try JSONEncoder().encode(
            dummyPayload
        ).base64URLEncodedString()

        let signature = try Hmac.sha256(
            data: headers + "." + payload,
            key: "abcdefghijklmnopqrstuvwxyz1234567890"
        ).digest().base64URLEncodedString()

        let jwt = headers + "." + payload + "." + signature
        var userId: String = ""
        stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt))
            .then { (uid: String) -> StitchTask<Void> in
            userId = uid
            return self.stitchClient.logout()
        }.then { _ -> StitchTask<String> in
            return self.stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt))
        }.then { (uid: String) in
            XCTAssertEqual(userId, uid)
            exp.fulfill()
        }.catch { err in
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
    }
}
