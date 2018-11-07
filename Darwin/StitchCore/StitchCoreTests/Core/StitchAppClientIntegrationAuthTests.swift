import Foundation
import XCTest
import JWT
import StitchCoreSDK
import MongoSwift
@testable import StitchCore

class StitchAppClientIntegrationAuthTests: StitchIntegrationTestCase {
    private func logoutAndCheckStorage() {
        let exp = expectation(description: "logged out")
        self.stitchAppClient.auth.logout { _ in
            self.verifyBasicAuthStorageInfo(loggedIn: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: defaultTimeoutSeconds)
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

        stitchAppClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success:
                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
                exp.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }

        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    func testUserProfile() throws {
        let exp = expectation(description: "verified profile information")

        stitchAppClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success(let user):
                XCTAssertEqual(user.profile.userType, "normal")
                XCTAssertEqual(user.profile.identities[0].providerType, "anon-user")
                exp.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }

        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    func testCustomLogin() throws {
        let jwt = JWT.encode(JWT.Algorithm.hs256(
            "abcdefghijklmnopqrstuvwxyz1234567890".data(using: .utf8)!)
        ) { (builder: JWT.ClaimSetBuilder) in
            builder.audience = harness.testApp?.clientAppID
            builder.notBefore = Date()
            builder.issuedAt = Date()
            builder.expiration = Date().addingTimeInterval(TimeInterval(60 * 5))
            builder["sub"] = "uniqueUserID"
            builder["stitch_meta"] = [
                "email": "name@example.com",
                "name": "Joe Bloggs",
                "picture_url": "https://goo.gl/xqR6Jd"
            ]
        }

        _ = self.harness.addDefaultCustomTokenProvider()

        let exp1 = expectation(description: "first custom login")
        var userID: String!
        self.stitchAppClient.auth.login(withCredential:
            CustomCredential.init(withToken: jwt)
        ) { result in
            switch result {
            case .success(let user):
                userID = user.id

                // Verify profile information in metadata
                let profile = user.profile
                XCTAssertEqual(profile.email, "name@example.com")
                XCTAssertEqual(profile.name, "Joe Bloggs")
                XCTAssertEqual(profile.pictureURL, "https://goo.gl/xqR6Jd")

                exp1.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let exp2 = expectation(description: "second custom login")
        stitchAppClient.auth.logout { _ in
            self.stitchAppClient.auth.login(withCredential:
                CustomCredential(withToken: jwt)
            ) { result in
                switch result {
                case .success(let user):
                    // Ensure that the same user logs in if the token has the same unique user ID.
                    XCTAssertEqual(userID, user.id)
                    exp2.fulfill()
                case .failure:
                    XCTFail("unexpected error")
                }
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }

    func testMultipleLoginSemantics() throws {
        // check storage
        verifyBasicAuthStorageInfo(loggedIn: false)

        // login anonymously
        let exp1 = expectation(description: "log in anonymously")
        var anonUserID: String!
        self.stitchAppClient.auth.login(
            withCredential: AnonymousCredential()
        ) { result in
            switch result {
            case .success(let user):
                anonUserID = user.id
                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
                exp1.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        // login anonymously again
        let exp2 = expectation(description: "log in anonymously again")

        self.stitchAppClient.auth.login(
            withCredential: AnonymousCredential()
        ) { result in
            switch result {
            case .success(let user):
                // make sure user ID is the name
                XCTAssertEqual(anonUserID, user.id)

                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
                exp2.fulfill()

            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "logged in as email/password user")
        var emailUserID: String!
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            let nextUserID = user.id
            XCTAssertNotEqual(anonUserID, nextUserID)
            emailUserID = nextUserID

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "logged in as second email/password user")
        self.registerAndLogin(email: "test2@10gen.com", password: "hunter2") { user in
            let nextUserID = user.id
            XCTAssertNotEqual(emailUserID, nextUserID)

            self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        logoutAndCheckStorage()
    }

    func testIdentityLinking() throws {
        let exp1 = expectation(description: "logged in with anonymous provider")
        var anonUser: StitchUser!
        self.stitchAppClient.auth.login(
            withCredential: AnonymousCredential()
        ) { result in
            switch result {
            case .success(let user):
                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.anonymous)
                anonUser = user
                exp1.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let userPassClient = self.stitchAppClient.auth.providerClient(
            fromFactory: userPasswordClientFactory
        )

        let exp2 = expectation(description: "new email/password identity is created and confirmed")
        userPassClient.register(withEmail: "stitch@10gen.com", withPassword: "password") { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }

            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "new email/password identity is confirmed")
        let conf = try? self.harness.app.userRegistrations.sendConfirmation(toEmail: "stitch@10gen.com")
        guard let safeConf = conf else {
            XCTFail("could not retrieve email confirmation token")
            return
        }

        userPassClient.confirmUser(withToken: safeConf.token, withTokenID: safeConf.tokenID) { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }

            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "original account linked with new email/password identity")
        anonUser.link(
            withCredential: UserPasswordCredential(withUsername: "stitch@10gen.com", withPassword: "password")
        ) { result in
            switch result {
            case .success(let linkedUser):
                XCTAssertEqual(anonUser.id, linkedUser.id)
                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
                XCTAssertEqual(linkedUser.profile.identities.count, 2)
                exp4.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        logoutAndCheckStorage()
    }
}
