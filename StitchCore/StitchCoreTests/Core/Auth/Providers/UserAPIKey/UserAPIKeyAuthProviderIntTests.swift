import MongoSwift
import Foundation
import XCTest
import StitchCoreSDK
import StitchCore

class UserAPIKeyAuthProviderIntTests: StitchIntegrationTestCase {
    override func setUp() {
        super.setUp()
        _ = harness.enableDefaultAPIKeyProvider()

    }
    // Test creating and logging in with an API key
    func testCreateAPIKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        var emailUserID: String!
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            emailUserID = user.id
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
            XCTFail("could not get user API key client")
            return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        var apiKey: UserAPIKey!
        userAPIKeyClient.createAPIKey(withName: "key_test") { key, _ in
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
            XCTAssertEqual(user?.id, emailUserID)
            exp3.fulfill()
        }

        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }

    func testFetchAPIKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and fetched it")
        userAPIKeyClient.createAPIKey(withName: "key_test") { createdKey, _ in
            XCTAssertNotNil(createdKey)
            XCTAssertNotNil(createdKey?.key)

            userAPIKeyClient.fetchAPIKey(withID: createdKey!.id) { fetchedKey, _ in
                XCTAssertNotNil(fetchedKey)
                XCTAssertEqual(createdKey?.id, fetchedKey?.id)
                XCTAssertEqual(createdKey?.name, fetchedKey?.name)
                XCTAssertNil(fetchedKey?.key)
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }

    func testFetchAPIKeys() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created two user API keys")
        var expectedID1: ObjectId!
        var expectedID2: ObjectId!
        userAPIKeyClient.createAPIKey(withName: "key_test") { createdKey, _ in
            XCTAssertNotNil(createdKey)
            XCTAssertNotNil(createdKey?.key)
            expectedID1 = createdKey!.id

            userAPIKeyClient.createAPIKey(withName: "key_test2") { createdKey2, _ in
                XCTAssertNotNil(createdKey2)
                XCTAssertNotNil(createdKey2?.key)
                expectedID2 = createdKey2!.id
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "fetched the two created user API keys")
        userAPIKeyClient.fetchAPIKeys { fetchedKeys, _ in
            XCTAssertEqual(fetchedKeys?.count, 2)
            fetchedKeys?.forEach({ key in
                XCTAssertTrue(key.id == expectedID1 || key.id == expectedID2)
            })
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }

    func testEnableDisableDeleteAPIKey() {
        let exp1 = expectation(description: "logged in as email/password user")
        self.registerAndLogin(email: "test1@10gen.com", password: "hunter1") { user in
            XCTAssertNotNil(user)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let auth = self.harness.stitchAppClient.auth
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key")
        var apiKey: UserAPIKey!
        userAPIKeyClient.createAPIKey(withName: "key_test") { key, _ in
            XCTAssertNotNil(key)
            XCTAssertNotNil(key?.key)
            apiKey = key
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "disabled user API key")
        userAPIKeyClient.disableAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKey(withID: apiKey.id, { key, _ in
                XCTAssertNotNil(key)
                XCTAssertTrue(key!.disabled)
                exp3.fulfill()
            })
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "enabled user API key")
        userAPIKeyClient.enableAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKey(withID: apiKey.id, { key, _ in
                XCTAssertNotNil(key)
                XCTAssertFalse(key!.disabled)
                exp4.fulfill()
            })
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        let exp5 = expectation(description: "deleted user API key")
        userAPIKeyClient.deleteAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKeys { keys, _ in
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
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userAPIKeyClient.createAPIKey(withName: "$$%%$$$") { _, error in
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
        guard let userAPIKeyClient = try? auth.providerClient(
            forFactory: UserAPIKeyAuthProvider.clientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userAPIKeyClient.fetchAPIKey(withID: ObjectId.init()) { _, error in
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
}
