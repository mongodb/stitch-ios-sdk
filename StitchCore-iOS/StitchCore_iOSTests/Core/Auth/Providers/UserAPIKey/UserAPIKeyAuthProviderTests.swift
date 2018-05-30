import MongoSwift
import Foundation
import XCTest
import StitchCore
import StitchCore_iOS

class UserAPIKeyAuthProviderTests: StitchIntegrationTestCase {
    override func setUp() {
        super.setUp()
        _ = harness.enableDefaultApiKeyProvider()

    }
    // Test creating and logging in with an API key
    func testCreateApiKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        var emailUserId: String!
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            emailUserId = user.id
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
            XCTFail("could not get user API key client")
            return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        var apiKey: UserAPIKey!
        userApiKeyClient.createApiKey(withName: "key_test") { key, _ in
            XCTAssertNotNil(key)
            XCTAssertNotNil(key?.key)
            apiKey = key
            auth.logout({ _ in
                exp2.fulfill()
            })
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "logged in using user API key")
        auth.login(withCredential: UserAPIKeyCredential(withKey: apiKey.key!)) { user, _ in
            XCTAssertNotNil(user)
            XCTAssertEqual(user?.id, emailUserId)
            exp3.fulfill()
        }

        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }

    func testFetchApiKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and fetched it")
        userApiKeyClient.createApiKey(withName: "key_test") { createdKey, _ in
            XCTAssertNotNil(createdKey)
            XCTAssertNotNil(createdKey?.key)

            userApiKeyClient.fetchApiKey(withId: createdKey!.id) { fetchedKey, _ in
                XCTAssertNotNil(fetchedKey)
                XCTAssertEqual(createdKey?.id, fetchedKey?.id)
                XCTAssertEqual(createdKey?.name, fetchedKey?.name)
                XCTAssertNil(fetchedKey?.key)
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }

    func testFetchApiKeys() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created two user API keys")
        var expectedId1: ObjectId!
        var expectedId2: ObjectId!
        userApiKeyClient.createApiKey(withName: "key_test") { createdKey, _ in
            XCTAssertNotNil(createdKey)
            XCTAssertNotNil(createdKey?.key)
            expectedId1 = createdKey!.id

            userApiKeyClient.createApiKey(withName: "key_test2") { createdKey2, _ in
                XCTAssertNotNil(createdKey2)
                XCTAssertNotNil(createdKey2?.key)
                expectedId2 = createdKey2!.id
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "fetched the two created user API keys")
        userApiKeyClient.fetchApiKeys { fetchedKeys, _ in
            XCTAssertEqual(fetchedKeys?.count, 2)
            fetchedKeys?.forEach({ key in
                XCTAssertTrue(key.id == expectedId1 || key.id == expectedId2)
            })
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }

    func testEnableDisableDeleteApiKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key")
        var apiKey: UserAPIKey!
        userApiKeyClient.createApiKey(withName: "key_test") { key, _ in
            XCTAssertNotNil(key)
            XCTAssertNotNil(key?.key)
            apiKey = key
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "disabled user API key")
        userApiKeyClient.disableApiKey(withId: apiKey.id) { _ in
            userApiKeyClient.fetchApiKey(withId: apiKey.id, { key, _ in
                XCTAssertNotNil(key)
                XCTAssertTrue(key!.disabled)
                exp3.fulfill()
            })
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "enabled user API key")
        userApiKeyClient.enableApiKey(withId: apiKey.id) { _ in
            userApiKeyClient.fetchApiKey(withId: apiKey.id, { key, _ in
                XCTAssertNotNil(key)
                XCTAssertFalse(key!.disabled)
                exp4.fulfill()
            })
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        let exp5 = expectation(description: "deleted user API key")
        userApiKeyClient.deleteApiKey(withId: apiKey.id) { _ in
            userApiKeyClient.fetchApiKeys { keys, _ in
                XCTAssertNotNil(keys)
                XCTAssertEqual(keys?.count, 0)
                exp5.fulfill()
            }
        }
        wait(for: [exp5], timeout: defaultTimeoutSeconds)
    }

    func testCreateKeyWithInvalidName() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { _ in
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userApiKeyClient.createApiKey(withName: "$$%%$$$") { _, error in
            XCTAssertNotNil(error)
            guard let stitchErr = error as? StitchError else {
                XCTFail("wrong error thrown")
                return
            }

            guard case .serviceError(_, let code) = stitchErr else {
                XCTFail("wrong Stitch error type")
                return
            }

            XCTAssertEqual(code, StitchServiceErrorCode.invalidParameter)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }

    func testFetchNonexistentKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { _ in
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userApiKeyClient = try? auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userApiKeyClient.fetchApiKey(withId: ObjectId.init()) { _, error in
            XCTAssertNotNil(error)
            guard let stitchErr = error as? StitchError else {
                XCTFail("wrong error thrown")
                return
            }

            guard case .serviceError(_, let code) = stitchErr else {
                XCTFail("wrong Stitch error type")
                return
            }

            XCTAssertEqual(code, StitchServiceErrorCode.apiKeyNotFound)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }

    func testLoggedOut() {
        let auth = self.harness.stitchAppClient.auth

        XCTAssertThrowsError(try auth.providerClient(
            forProvider: UserAPIKeyAuthProvider.authenticatedClientSupplier), "") { error in
                XCTAssertTrue(error is StitchError)
                guard let stitchErr = error as? StitchError else {
                    XCTFail("Incorrect error type thrown")
                    return
                }

                guard case .clientError(let clientErrCode) = stitchErr else {
                    XCTFail("Incorrect error type thrown")
                    return
                }

                XCTAssertEqual(clientErrCode, .mustAuthenticateFirst)
        }
    }
}
