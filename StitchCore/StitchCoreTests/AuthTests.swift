import XCTest
import Foundation
import StitchLogger
import ExtendedJson
import JWT
@testable import StitchCore
import PromiseKit

class AuthTests: StitchTestCase {
    var stitchClient: StitchClient!
    var harness: TestHarness!

    override func setUp() {
        super.setUp()
        LogManager.minimumLogLevel = .debug
        self.harness = await(buildClientTestHarness())
        self.stitchClient = harness.stitchClient
        try! self.stitchClient.clearAuth()
    }

    override func tearDown() {
        try! self.stitchClient.clearAuth()
        await(self.harness.teardown())
    }

    func testFetchAuthProviders() throws {
        let authInfo = await(stitchClient.fetchAuthProviders())!
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
        
        XCTAssertNil(authInfo.customAuthProviderInfos)
        XCTAssertNil(authInfo.googleProviderInfo)
        XCTAssertNil(authInfo.facebookProviderInfo)
    }

    func testAnonymousLogin() throws {
        XCTAssertNotNil(
            await(stitchClient.login(withProvider: AnonymousAuthProvider()))
        )
    }

    func testUserProfile() throws {
        await(stitchClient.login(withProvider: AnonymousAuthProvider()))
        let userProfile = await(self.stitchClient.auth!.fetchUserProfile())!
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

        await(self.harness.configureCustomToken())
        let userId = await(stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt)))
        await(stitchClient.logout())
        let nextId = await(stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt)))
        XCTAssertEqual(userId, nextId)
    }
    
    func testMultipleLoginSemantics() throws {
        // check storage
        XCTAssertFalse(self.stitchClient.isAuthenticated)
        XCTAssertNil(self.stitchClient.loggedInProviderType)

        // login anonymously
        let anonUserId = await(self.stitchClient.login(withProvider: AnonymousAuthProvider()))
        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.anonymous)

        // login anonymously again
        var emailUserId = await(self.stitchClient.login(withProvider: AnonymousAuthProvider()))

        // make sure user ID is the same
        XCTAssertEqual(anonUserId, emailUserId)

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.anonymous)

        await(self.stitchClient.register(email: "test1@10gen.com", password: "hunter1"))
        let conf = await(self.harness.app.userRegistrations.sendConfirmation(toEmail: "test1@10gen.com"))!
        self.stitchClient.emailConfirm(token: conf.token, tokenId: conf.tokenId)

        // login with email provider
        var nextUserId = await(self.stitchClient.login(
            withProvider: EmailPasswordAuthProvider(username: "test1@10gen.com",
                                                    password: "hunter1")
        ))
        // make sure the user ID is updated
        XCTAssertNotEqual(anonUserId, nextUserId)
        emailUserId = nextUserId

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.emailPass)

        await(self.stitchClient.register(email: "test2@10gen.com", password: "hunter2"))
        let conf2 = await(self.harness.app.userRegistrations.sendConfirmation(toEmail: "test2@10gen.com"))!
        self.stitchClient.emailConfirm(token: conf2.token, tokenId: conf2.tokenId)
        
        // login with email provider under different user
        nextUserId = await(self.stitchClient.login(
            withProvider: EmailPasswordAuthProvider(username: "test2@10gen.com",
                                                    password: "hunter2"))
        )
        // make sure the user ID is updated
        XCTAssertNotEqual(emailUserId, nextUserId)

        // check storage
        XCTAssertTrue(self.stitchClient.isAuthenticated)
        XCTAssertEqual(self.stitchClient.loggedInProviderType, AuthProviderTypes.emailPass)

        // logout
        await(self.stitchClient.logout())
        // check storage
        XCTAssertFalse(self.stitchClient.isAuthenticated)
        XCTAssertNil(self.stitchClient.loggedInProviderType)
    }
}
