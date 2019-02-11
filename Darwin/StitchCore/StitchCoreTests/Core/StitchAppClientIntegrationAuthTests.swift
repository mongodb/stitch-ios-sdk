// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
// swiftlint:disable cyclomatic_complexity

import Foundation
import XCTest
import JWT
import StitchCoreSDK
import MongoSwift
@testable import StitchCore

class StitchAppClientIntegrationAuthTests: StitchIntegrationTestCase {
    private func verifyBasicAuthInfo(loggedInList: [Bool],
                                     loggedIn: Bool,
                                     expectedProviderType: StitchProviderType? = nil,
                                     expectedUserIndex: Int? = nil) {
        var ids: [String] = []
        let users = self.stitchAppClient.auth.listUsers()
        XCTAssertEqual(users.count, loggedInList.count)
        for (i, user) in users.enumerated() {
            XCTAssertEqual(user.isLoggedIn, loggedInList[i])
            ids.append(user.id)
        }

        XCTAssertEqual(self.stitchAppClient.auth.isLoggedIn, loggedIn)
        if loggedIn {
            guard
                let user = self.stitchAppClient.auth.currentUser,
                let providerType = expectedProviderType else {
                    XCTFail("must provide expected provider type to verify storage")
                    return
            }
            guard let userIdIndex = expectedUserIndex else {
                XCTFail("must provide expected user id index to verify storage")
                return
            }
            XCTAssertEqual(user.loggedInProviderType, providerType)
            XCTAssertEqual(user.id, ids[userIdIndex])
        } else {
            XCTAssertNil(self.stitchAppClient.auth.currentUser)
        }
    }

    func testAnonymousLogin() throws {
        let exp = expectation(description: "logged in anonymously")

        stitchAppClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success:
                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.anonymous,
                    expectedUserIndex: 1)
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
                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.anonymous,
                    expectedUserIndex: 1)
                XCTAssertNotNil(user.lastAuthActivity)
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

                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.custom,
                    expectedUserIndex: 1)

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

                    self.verifyBasicAuthInfo(
                        loggedInList: [false, true],
                        loggedIn: true,
                        expectedProviderType: StitchProviderType.custom,
                        expectedUserIndex: 1)

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
        self.verifyBasicAuthInfo(loggedInList: [false], loggedIn: false)

        // login anonymously
        let exp1 = expectation(description: "log in anonymously")
        var anonUserID: String!
        self.stitchAppClient.auth.login(
            withCredential: AnonymousCredential()
        ) { result in
            switch result {
            case .success(let user):
                anonUserID = user.id

                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.anonymous,
                    expectedUserIndex: 1)

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

                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.anonymous,
                    expectedUserIndex: 1)

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

            self.verifyBasicAuthInfo(
                loggedInList: [false, true, true],
                loggedIn: true,
                expectedProviderType: StitchProviderType.userPassword,
                expectedUserIndex: 2)

            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "switching to previous user should work properly")
        let newUser = try self.stitchAppClient.auth.switchToUser(withId: anonUserID)
        XCTAssertNotNil(newUser)
        self.verifyBasicAuthInfo(
            loggedInList: [false, true, true],
            loggedIn: true,
            expectedProviderType: StitchProviderType.anonymous,
            expectedUserIndex: 1)
        exp4.fulfill()
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        // Calling logout should delete the anonymous user that is active and leave the auth state empty
        let exp5 = expectation(description: "logging out of active anon user should delete it")
        self.stitchAppClient.auth.logout { result in
            switch result {
            case .success:
                self.verifyBasicAuthInfo(loggedInList: [false, true], loggedIn: false)
                exp5.fulfill()
            case .failure:
                XCTFail("Failed logging out")
            }
        }
        wait(for: [exp5], timeout: defaultTimeoutSeconds)

        // Calling logout on userPassword credentials will log it out but it will remain in listUsers()
        let exp6 = expectation(description: "logging out of active anon user should delete it")
        self.stitchAppClient.auth.logoutUser(withId: emailUserID) { result in
            switch result {
            case .success:
                self.verifyBasicAuthInfo(loggedInList: [false, false], loggedIn: false)
                exp6.fulfill()
            case .failure:
                XCTFail("Failed logging out")
            }
        }
        wait(for: [exp6], timeout: defaultTimeoutSeconds)

        // add new user
        let exp7 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test12@10gen.com", password: "hunter2") { _ in
            self.verifyBasicAuthInfo(
                loggedInList: [false, false, true],
                loggedIn: true,
                expectedProviderType: StitchProviderType.userPassword,
                expectedUserIndex: 2)

            exp7.fulfill()
        }
        wait(for: [exp7], timeout: defaultTimeoutSeconds)

        // removing active user
        let exp8 = expectation(description: "removing active user")
        self.stitchAppClient.auth.removeUser { result in
            switch result {
            case .success:
                self.verifyBasicAuthInfo(loggedInList: [false, false], loggedIn: false)
                exp8.fulfill()
            case .failure:
                XCTFail("Failed logging out")
            }
        }
        wait(for: [exp8], timeout: defaultTimeoutSeconds)

        // removing other user
        let exp9 = expectation(description: "removing active user")
        self.stitchAppClient.auth.removeUser(withId: emailUserID) { result in
            switch result {
            case .success:
                self.verifyBasicAuthInfo(loggedInList: [false], loggedIn: false)
                exp9.fulfill()
            case .failure:
                XCTFail("Failed logging out")
            }
        }
        wait(for: [exp9], timeout: defaultTimeoutSeconds)
    }

    func testIdentityLinking() throws {
        let exp1 = expectation(description: "logged in with anonymous provider")
        var anonUser: StitchUser!
        self.stitchAppClient.auth.login(
            withCredential: AnonymousCredential()
        ) { result in
            switch result {
            case .success(let user):

                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: StitchProviderType.anonymous,
                    expectedUserIndex: 1)

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
        anonUser.link(withCredential:
            UserPasswordCredential(withUsername: "stitch@10gen.com", withPassword: "password")) {result in
            switch result {
            case .success(let linkedUser):
                XCTAssertEqual(anonUser.id, linkedUser.id)
                self.verifyBasicAuthInfo(
                    loggedInList: [false, true],
                    loggedIn: true,
                    expectedProviderType: .userPassword,
                    expectedUserIndex: 1)

                XCTAssertEqual(linkedUser.profile.identities.count, 2)
                exp4.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)
    }
}
