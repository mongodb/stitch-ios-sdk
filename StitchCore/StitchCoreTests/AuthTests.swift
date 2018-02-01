import XCTest
import Foundation
import StitchLogger
import ExtendedJson
import JWT
@testable import StitchCore
import PromiseKit

class AuthTests: XCTestCase {
    var stitchClient: StitchClient!

    override func setUp() {
        super.setUp()
        LogManager.minimumLogLevel = .debug
        let expectation = self.expectation(description: "should create stitchClient")
        StitchClientFactory.create(appId: "test-uybga").done {
            self.stitchClient = $0
            try! self.stitchClient.clearAuth()
            expectation.fulfill()
        }.cauterize()
        wait(for: [expectation], timeout: 10)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testFetchAuthProviders() throws {
        let exp = expectation(description: "fetched auth providers")
        stitchClient.fetchAuthProviders().done { (authInfo: AuthProviderInfo) in
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
        stitchClient.login(withProvider: AnonymousAuthProvider()).done { (userId: String) in
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
        stitchClient.login(withProvider: AnonymousAuthProvider()).then { _ in
            (self.stitchClient.auth?.fetchUserProfile())!
        }.done { (userProfile: UserProfile) in
            XCTAssertEqual("normal", userProfile.type)
            print(userProfile)
            XCTAssertEqual("anon-user", userProfile.identities[0].providerType)
            print(userProfile)
            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
            exit(1)
        }

        wait(for: [exp], timeout: 200)
    }

    func testCustomLogin() throws {
        let exp = expectation(description: "logged in")

        let jwt = JWT.encode(Algorithm.hs256(
            "abcdefghijklmnopqrstuvwxyz1234567890".data(using: .utf8)!)
        ) { (builder: ClaimSetBuilder) in
            builder.audience = "test-uybga"
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

        var userId: String = ""
        stitchClient.login(
            withProvider: CustomAuthProvider(jwt: jwt)
        ).then { (uid: String) throws -> Promise<Void> in
            userId = uid
            return self.stitchClient.logout()
        }.then { _ in
            return self.stitchClient.login(withProvider: CustomAuthProvider(jwt: jwt))
        }.done { (uid: String) in
            XCTAssertEqual(userId, uid)
            exp.fulfill()
        }.catch { err in
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
    }
    
    func testMultipleLoginSemantics() throws {
        let exp = expectation(description: "multiple logins work as expected")
        let mlsStitchClient = StitchClient(appId: "stitch-tests-ios-sdk-jjmum")
        var anonUserId = ""
        var emailUserId = ""
        
        // check storage
        XCTAssertFalse(mlsStitchClient.isAuthenticated)
        XCTAssertNil(mlsStitchClient.loggedInProviderType)
        
        // login anonymously
        mlsStitchClient.login(withProvider: AnonymousAuthProvider()).then { (userId: String) -> Promise<String> in
            anonUserId = userId
            
            // check storage
            XCTAssertTrue(mlsStitchClient.isAuthenticated)
            XCTAssertEqual(mlsStitchClient.loggedInProviderType, AuthProviderTypes.anonymous)
            
            // login anonymously again
            return mlsStitchClient.login(withProvider: AnonymousAuthProvider())
        }.then { (userId: String) -> Promise<String> in
            // make sure user ID is the same
            XCTAssertEqual(anonUserId, userId)
            
            // check storage
            XCTAssertTrue(mlsStitchClient.isAuthenticated)
            XCTAssertEqual(mlsStitchClient.loggedInProviderType, AuthProviderTypes.anonymous)
            
            // login with email provider
            return mlsStitchClient.login(withProvider: EmailPasswordAuthProvider(username: "test1@example.com", password: "hunter1"))
        }.then{ (userId: String) -> Promise<String> in
            // make sure the user ID is updated
            XCTAssertNotEqual(anonUserId, userId)
            emailUserId = userId
            
            // check storage
            XCTAssertTrue(mlsStitchClient.isAuthenticated)
            XCTAssertEqual(mlsStitchClient.loggedInProviderType, AuthProviderTypes.emailPass)
            
            // login with email provider under different user
            return mlsStitchClient.login(withProvider: EmailPasswordAuthProvider(username: "test2@example.com", password: "hunter2"))
        }.then{ (userId: String) -> Promise<Void> in
            // make sure the user ID is updated
            XCTAssertNotEqual(emailUserId, userId)
            
            // check storage
            XCTAssertTrue(mlsStitchClient.isAuthenticated)
            XCTAssertEqual(mlsStitchClient.loggedInProviderType, AuthProviderTypes.emailPass)
            
            // logout
            return mlsStitchClient.logout()
        }.done {
            // check storage
            XCTAssertFalse(mlsStitchClient.isAuthenticated)
            XCTAssertNil(mlsStitchClient.loggedInProviderType)
            
            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10)
    }
}
