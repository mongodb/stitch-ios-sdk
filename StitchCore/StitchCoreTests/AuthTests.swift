//
//  AuthTests.swift
//  StitchCoreTests
//
//  Created by Jason Flax on 11/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

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

    let stitchClient = StitchClient(appId: "test-jsf-fpleb", baseUrl: "https://stitch-dev.mongodb.com")

    func testFetchAuthProviders() throws {
        let exp = expectation(description: "fetched auth providers")
        stitchClient.fetchAuthProviders().then { (authInfo: AuthProviderInfo) in
            let anon = authInfo.anonymousAuthProviderInfo
            XCTAssertNotNil(anon)
            XCTAssertEqual(anon?.name, "anon-user")
            XCTAssertEqual(anon?.type, "anon-user")
            XCTAssertFalse(anon?.disabled ?? true)
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
}
