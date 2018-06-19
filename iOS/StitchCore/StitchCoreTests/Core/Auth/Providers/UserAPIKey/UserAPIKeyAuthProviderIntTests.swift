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
            forFactory: userAPIKeyClientFactory) else {
            XCTFail("could not get user API key client")
            return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        var apiKey: UserAPIKey!
        userAPIKeyClient.createAPIKey(withName: "key_test") { result in
            switch result {
            case .success(let key):
                XCTAssertNotNil(key.key)
                apiKey = key
            case .failure:
                XCTFail("unexpected error")
            }

            auth.logout({ _ in
                exp2.fulfill()
            })
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "logged in using user API key")
        auth.login(withCredential: UserAPIKeyCredential(withKey: apiKey.key!)) { result in
            switch result {
            case .success(let user):
                XCTAssertEqual(user.id, emailUserID)
            case .failure:
                XCTFail("unexpected error")
            }
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
            forFactory: userAPIKeyClientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and fetched it")
        userAPIKeyClient.createAPIKey(withName: "key_test") { result in
            switch result {
            case .success(let createdKey):
                XCTAssertNotNil(createdKey.key)
                userAPIKeyClient.fetchAPIKey(withID: createdKey.id) { result in
                    switch result {
                    case .success(let fetchedKey):
                        XCTAssertEqual(createdKey.id, fetchedKey.id)
                        XCTAssertEqual(createdKey.name, fetchedKey.name)
                        XCTAssertNil(fetchedKey.key)
                        exp2.fulfill()
                    case .failure:
                        XCTFail("unexpected error")
                    }
                }
            case .failure:
                XCTFail("unexpected error")
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
            forFactory: userAPIKeyClientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created two user API keys")
        var expectedID1: ObjectId!
        var expectedID2: ObjectId!
        userAPIKeyClient.createAPIKey(withName: "key_test") { result in
            switch result {
            case .success(let createdKey):
                XCTAssertNotNil(createdKey.key)
                expectedID1 = createdKey.id
            case .failure:
                XCTFail("unexpected error")
            }

            userAPIKeyClient.createAPIKey(withName: "key_test2") { result in
                switch result {
                case .success(let createdKey2):
                    XCTAssertNotNil(createdKey2.key)
                    expectedID2 = createdKey2.id
                    exp2.fulfill()
                case .failure:
                    XCTFail("unexpected error")
                }
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "fetched the two created user API keys")
        userAPIKeyClient.fetchAPIKeys { result in
            switch result {
            case .success(let fetchedKeys):
                XCTAssertEqual(fetchedKeys.count, 2)
                fetchedKeys.forEach({ key in
                    XCTAssertTrue(key.id == expectedID1 || key.id == expectedID2)
                })
                exp3.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
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
            forFactory: userAPIKeyClientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key")
        var apiKey: UserAPIKey!
        userAPIKeyClient.createAPIKey(withName: "key_test") { result in
            switch result {
            case .success(let key):
                XCTAssertNotNil(key.key)
                apiKey = key
                exp2.fulfill()
            case .failure:
                XCTFail("unexpected error")
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "disabled user API key")
        userAPIKeyClient.disableAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKey(withID: apiKey.id, { result in
                switch result {
                case .success(let key1):
                    XCTAssertTrue(key1.disabled)
                    exp3.fulfill()
                case .failure:
                    XCTFail("unexpected error")
                }
            })
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "enabled user API key")
        userAPIKeyClient.enableAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKey(withID: apiKey.id, { result in
                switch result {
                case .success(let key):
                    XCTAssertFalse(key.disabled)
                    exp4.fulfill()
                case .failure:
                    XCTFail("unexpected error")
                }
            })
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        let exp5 = expectation(description: "deleted user API key")
        userAPIKeyClient.deleteAPIKey(withID: apiKey.id) { _ in
            userAPIKeyClient.fetchAPIKeys { result in
                switch result {
                case .success(let keys):
                    XCTAssertEqual(keys.count, 0)
                    exp5.fulfill()
                case .failure:
                    XCTFail("unexpected error")
                }
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
            forFactory: userAPIKeyClientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userAPIKeyClient.createAPIKey(withName: "$$%%$$$") { result in
            switch result {
            case .success:
                XCTFail("unexpected error")
            case .failure(let error):
                guard case .serviceError(_, let code) = error else {
                    XCTFail("wrong Stitch error type")
                    return
                }

                XCTAssertEqual(code, StitchServiceErrorCode.invalidParameter)
                exp2.fulfill()
            }
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
            forFactory: userAPIKeyClientFactory) else {
                XCTFail("could not get user API key client")
                return
        }

        let exp2 = expectation(description: "created user API key, and logged out")
        userAPIKeyClient.fetchAPIKey(withID: ObjectId.init()) { result in // _, error in
            switch result {
            case .success:
                XCTFail("unexpected error")
            case .failure(let error):
                guard case .serviceError(_, let code) = error else {
                    XCTFail("wrong Stitch error type")
                    return
                }

                XCTAssertEqual(code, StitchServiceErrorCode.apiKeyNotFound)
                exp2.fulfill()
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)
    }
}
