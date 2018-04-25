import Foundation
import XCTest
//import JWT
import StitchCore
import ExtendedJSON
@testable import StitchCore_iOS

class StitchAppClientIntegrationTests: XCTestCase {
    private var harness: TestHarness!
    private var stitchAppClient: StitchAppClient!

    private static let email = "stitch@10gen.com"
    private static let pass = "stitchuser"

    override func setUp() {
        let exp = expectation(description: "set up integration tests")
        buildClientTestHarness { harness in
            self.harness = harness
            self.stitchAppClient = harness.stitchAppClient
            self.stitchAppClient.auth.logout { _ in
                exp.fulfill()
            }

        }
        wait(for: [exp], timeout: 10.0)
    }

    override func tearDown() {
        let exp = expectation(description: "tore down integration tests")
        self.stitchAppClient.auth.logout { _ in
            self.harness.teardown()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10.0)
    }

    private func registerAndLogin(email: String = email,
                                  password: String = pass,
                                  _ completionHandler: @escaping (StitchUser) -> Void) {
        let emailPassClient = self.stitchAppClient.auth.providerClient(
            forProvider: UserPasswordAuthProvider.clientSupplier
        )
        emailPassClient.register(withEmail: email, withPassword: password) { _ in
            let conf = try? self.harness.app.userRegistrations.sendConfirmation(toEmail: email)
            guard let safeConf = conf else { XCTFail("could not retrieve email confirmation token"); return }
            emailPassClient.confirmUser(withToken: safeConf.token,
                                        withTokenId: safeConf.tokenId
                ) { _ in
                self.stitchAppClient.auth.login(
                    withCredential: emailPassClient.credential(forUsername: email, forPassword: password)
                ) { user, _ in
                    guard let user = user else {
                        XCTFail("Failed to log in with username/password provider")
                        return
                    }
                    completionHandler(user)
                }
            }
        }
    }

    private func logoutAndCheckStorage() {
        let exp = expectation(description: "logged out")
        self.stitchAppClient.auth.logout { _ in
            self.verifyBasicAuthStorageInfo(loggedIn: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    private func verifyBasicAuthStorageInfo(loggedIn: Bool,
                                            expectedProviderType: StitchProviderType? = nil) {
        XCTAssertEqual(self.stitchAppClient.auth.isLoggedIn, loggedIn)
        if loggedIn {
            guard
                let user = self.stitchAppClient.auth.currentUser,
                let providerType = expectedProviderType else {
                XCTFail("must provide expected provider type to verify storage")
                    return
            }
            XCTAssertEqual(user.loggedInProviderType, providerType)
        } else {
            XCTAssertNil(self.stitchAppClient.auth.currentUser)
        }
    }

    func testAnonymousLogin() throws {
        let exp = expectation(description: "logged in anonymously")

        let anonAuthClient = stitchAppClient.auth.providerClient(forProvider: AnonymousAuthProvider.clientSupplier)
        stitchAppClient.auth.login(withCredential: anonAuthClient.credential) { user, _ in
            XCTAssertNotNil(user)
            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10.0)
    }

    func testUserProfile() throws {
        let exp = expectation(description: "verified profile information")

        let anonAuthClient = stitchAppClient.auth.providerClient(forProvider: AnonymousAuthProvider.clientSupplier)
        stitchAppClient.auth.login(withCredential: anonAuthClient.credential) { user, _ in
            XCTAssertNotNil(user)
            XCTAssertEqual(user!.profile.userType, "normal")
            XCTAssertEqual(user!.profile.identities[0].providerType, "anon-user")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10.0)
    }

//    func testCustomLogin() throws {
//        let jwt = JWT.encode(Algorithm.hs256(
//            "abcdefghijklmnopqrstuvwxyz1234567890".data(using: .utf8)!)
//        ) { (builder: ClaimSetBuilder) in
//            builder.audience = harness.testApp?.clientAppId
//            builder.notBefore = Date()
//            builder.issuedAt = Date()
//            builder.expiration = Date().addingTimeInterval(TimeInterval(60 * 5))
//            builder["sub"] = "uniqueUserID"
//            builder["stitch_meta"] = [
//                "email": "name@example.com",
//                "name": "Joe Bloggs",
//                "picture": "https://goo.gl/xqR6Jd"
//            ]
//        }
//
//        self.harness.addDefaultCustomTokenProvider()
//        let customAuthClient = self.stitchAppClient.auth.providerClient(forProvider:
//            CustomAuthProvider.clientSupplier
//        )
//
//        let exp1 = expectation(description: "first custom login")
//        var userId: String!
//        self.stitchAppClient.auth.login(withCredential:
//            customAuthClient.credential(withToken: jwt)
//        ) { user, error in
//            XCTAssertNotNil(user)
//            userId = user.id
//            exp1.fulfill()
//        }
//        wait(for: [exp1], timeout: 10.0)
//
//        let exp2 = expectation(description: "second custom login")
//        stitchAppClient.auth.logout { _ in
//            self.stitchAppClient.auth.login(withCredential:
//                customAuthClient.credential(withToken: jwt)
//            ) { user, error in
//                XCTAssertNotNil(user)
//                XCTAssertEqual(userId, user!.id)
//
//                // TODO: Verify profile information in metadata
//                exp2.fulfill()
//            }
//        }
//        wait(for: [exp2], timeout: 10.0)
//    }

    func testMultipleLoginSemantics() throws {
        // check storage
        verifyBasicAuthStorageInfo(loggedIn: false)

        // login anonymously
        let exp1 = expectation(description: "log in anonymously")
        var anonUserId: String!
        self.stitchAppClient.auth.login(
            withCredential: self.stitchAppClient.auth.providerClient(forProvider:
                AnonymousAuthProvider.clientSupplier).credential
        ) { (user: StitchUser?, _) in
            XCTAssertNotNil(user)
            anonUserId = user!.id

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 10.0)

        // login anonymously again
        let exp2 = expectation(description: "log in anonymously again")

        self.stitchAppClient.auth.login(
            withCredential: self.stitchAppClient.auth.providerClient(forProvider:
                AnonymousAuthProvider.clientSupplier).credential
        ) { (user: StitchUser?, _) in
            XCTAssertNotNil(user)

            // make sure user ID is the name
            XCTAssertEqual(anonUserId, user!.id)

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 10.0)

        let exp3 = expectation(description: "logged in as email/password user")
        var emailUserId: String!
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            let nextUserId = user.id
            XCTAssertNotEqual(anonUserId, nextUserId)
            emailUserId = nextUserId

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 10.0)

        let exp4 = expectation(description: "logged in as second email/password user")
        self.registerAndLogin(email: "test2@10gen.com", password: "hunter2") { user in
            let nextUserId = user.id
            XCTAssertNotEqual(emailUserId, nextUserId)

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: 10.0)

        logoutAndCheckStorage()
    }

    func testIdentityLinking() throws {
        let exp1 = expectation(description: "logged in with anonymous provider")
        var anonUser: StitchUser!
        self.stitchAppClient.auth.login(
            withCredential: self.stitchAppClient.auth.providerClient(
                forProvider: AnonymousAuthProvider.clientSupplier).credential
        ) { (user, _) in
            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
            anonUser = user
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 10.0)

        let userPassClient = self.stitchAppClient.auth.providerClient(
            forProvider: UserPasswordAuthProvider.clientSupplier
        )

        let exp2 = expectation(description: "new email/password identity is created and confirmed")
        userPassClient.register(withEmail: "stitch@10gen.com", withPassword: "password") { error in
            XCTAssertNil(error)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 10.0)

        let exp3 = expectation(description: "new email/password identity is confirmed")
        let conf = try? self.harness.app.userRegistrations.sendConfirmation(toEmail: "stitch@10gen.com")
        guard let safeConf = conf else {
            XCTFail("could not retrieve email confirmation token")
            return
        }

        userPassClient.confirmUser(withToken: safeConf.token, withTokenId: safeConf.tokenId) { error in
            XCTAssertNil(error)
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 10.0)

        let exp4 = expectation(description: "original account linked with new email/password identity")
        anonUser.link(
            withCredential: userPassClient.credential(forUsername: "stitch@10gen.com", forPassword: "password")
        ) { linkedUser, _ in
            XCTAssertNotNil(linkedUser)
            XCTAssertEqual(anonUser.id, linkedUser!.id)
            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
            XCTAssertEqual(linkedUser?.profile.identities.count, 2)
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: 10.0)

        logoutAndCheckStorage()
    }

    func testCallFunction() {
        _ = self.harness.addTestFunction()

        let exp1 = expectation(description: "logged in anonymously")
        let anonAuthClient = stitchAppClient.auth.providerClient(forProvider: AnonymousAuthProvider.clientSupplier)
        stitchAppClient.auth.login(withCredential: anonAuthClient.credential) { user, _ in
            XCTAssertNotNil(user)
            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 10.0)

        let exp2 = expectation(description: "called function successfully")
        let randomInt = Int(arc4random())
        stitchAppClient.callFunction(withName: "testFunction", withArgs: [randomInt, "hello"]) { document, _ in
            XCTAssertNotNil(document)

            // STITCH-1345: when doAuthenticatedJSONRequest and `callFunction` returns a T: BSONCodable or
            // T: ExtendedJSONRepresentable, this test should be updated so the result need not be manually decoded
            guard let docMap = document as? [String: Any] else {
                XCTFail("Could not read document as map of string to Any")
                return
            }

            XCTAssertEqual(docMap["stringValue"] as? String, "hello")

            guard let intValue = docMap["intValue"] as? [String: Any] else {
                XCTFail("Int result missing in function return value")
                return
            }

            XCTAssertEqual(intValue["$numberLong"] as? String, String(randomInt))

            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 10.0)
    }
}
