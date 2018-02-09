import XCTest
import Foundation
import ExtendedJson
import JWT
@testable import StitchCore
import PromiseKit

class AuthTests: StitchTestCase {
    func testFetchAuthProviders() throws {
        let authInfo = try await(stitchClient.fetchAuthProviders())
        let anon = authInfo.anonymousAuthProviderInfo
        XCTAssertNotNil(anon)
        XCTAssertEqual(anon?.name, "anon-user")
        XCTAssertEqual(anon?.type, "anon-user")
        XCTAssertNotNil(authInfo.emailPasswordAuthProviderInfo)
        XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.config.emailConfirmationUrl,
                       "http://emailConfirmURL.com")
        XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.config.resetPasswordUrl,
                       "http://resetPasswordURL.com")
        XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.name, "local-userpass")
        XCTAssertEqual(authInfo.emailPasswordAuthProviderInfo?.type, "local-userpass")
        
        XCTAssertEqual(authInfo.customAuthProviderInfos.count, 0)
        XCTAssertNil(authInfo.googleProviderInfo)
        XCTAssertNil(authInfo.facebookProviderInfo)
    }

    func testAnonymousLogin() throws {
        XCTAssertNoThrow(
            try await(stitchClient.login(withProvider: AnonymousAuthProvider()))
        )
    }

    func testUserProfile() throws {
        try await(stitchClient.login(withProvider: AnonymousAuthProvider()))
        let userProfile = try await(self.stitchClient.auth!.fetchUserProfile())
        XCTAssertEqual("normal", userProfile.type)
        XCTAssertEqual("anon-user", userProfile.identities[0].providerType)
    }

    func testCustomLogin() throws {
        let jwt = JWT.encode(Algorithm.hs256(
            "abcdefghijklmnopqrstuvwxyz1234567890".data(using: .utf8)!)
        ) { (builder: ClaimSetBuilder) in
            builder.audience = harness.testApp?.clientAppId
            builder.notBefore = Date()
            builder.issuedAt = Date()
            builder.expiration = Date().addingTimeInterval(TimeInterval(60 * 5))
            builder["sub"] = "uniqueUserID"
            builder["stitch_meta"] = [
                "email": "name@example.com",
                "name": "Joe Bloggs",
                "picture": "https://goo.gl/xqR6Jd"
            ]
        }

        try await(self.harness.addDefaultCustomTokenProvider())
        let userId = try await(stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt)))
        try await(stitchClient.logout())
        let nextId = try await(stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt)))
        XCTAssertEqual(userId, nextId)
    }
    
    func testMultipleLoginSemantics() throws {
        // check storage
        XCTAssertFalse(self.stitchClient.isAuthenticated)
        XCTAssertNil(self.stitchClient.loggedInProviderType)

        // login anonymously
        let anonUserId = try await(self.stitchClient.login(withProvider: AnonymousAuthProvider()))
        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.anonymous)

        // login anonymously again
        var emailUserId = try await(self.stitchClient.login(withProvider: AnonymousAuthProvider()))

        // make sure user ID is the same
        XCTAssertEqual(anonUserId, emailUserId)

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.anonymous)

        try await(self.stitchClient.registerAndConfirm(email: "test1@10gen.com",
                                                       password: "hunter1",
                                                       withHarness: self.harness))

        // login with email provider
        var nextUserId = try await(self.stitchClient.login(
            withProvider: EmailPasswordAuthProvider(username: "test1@10gen.com",
                                                    password: "hunter1")
        ))
        // make sure the user ID is updated
        XCTAssertNotEqual(anonUserId, nextUserId)
        emailUserId = nextUserId

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.emailPass)

        try await(self.stitchClient.registerAndConfirm(email: "test2@10gen.com",
                                                       password: "hunter2",
                                                       withHarness: self.harness))
        
        // login with email provider under different user
        nextUserId = try await(self.stitchClient.login(
            withProvider: EmailPasswordAuthProvider(username: "test2@10gen.com",
                                                    password: "hunter2"))
        )
        // make sure the user ID is updated
        XCTAssertNotEqual(emailUserId, nextUserId)

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.emailPass)

        // logout
        try await(self.stitchClient.logout())

        // check storage
        XCTAssertFalse(self.stitchClient.isAuthenticated)
        XCTAssertNil(self.stitchClient.loggedInProviderType)
    }

    func testIdentityLinking() throws {
        let firstUserId = try await(stitchClient.login(withProvider: AnonymousAuthProvider()))
        XCTAssertEqual(stitchClient.loggedInProviderType, AuthProviderTypes.anonymous)

        try await(self.stitchClient.registerAndConfirm(email: "link_test@10gen.com",
                                                        password: "hunter2",
                                                        withHarness: self.harness))

        let newUserId = try await(
            self.stitchClient.link(withProvider: EmailPasswordAuthProvider(username: "link_test@10gen.com",
                                                                            password: "hunter2"))
        )
        XCTAssertEqual(firstUserId, newUserId)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.emailPass)

        let userProfile =  try await(self.stitchClient.auth!.fetchUserProfile())
        XCTAssertEqual(userProfile.identities.count, 2)

        try await(self.stitchClient.logout())
        XCTAssertFalse(self.stitchClient.isAuthenticated)
    }
}
