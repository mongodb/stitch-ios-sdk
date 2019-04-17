// swiftlint:disable file_length
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
import Foundation
import XCTest
import JWT
import StitchCoreSDK
import MongoSwift
@testable import StitchCore

class StitchAppClientIntegrationTests: StitchIntegrationTestCase {
    public override func registerAndLogin(email: String = email,
                                          password: String = pass,
                                          _ completionHandler: @escaping (StitchUser) -> Void) {
        let emailPassClient = self.stitchAppClient.auth.providerClient(
            fromFactory: userPasswordClientFactory
        )
        emailPassClient.register(withEmail: email, withPassword: password) { _ in
            let conf = try? self.harness.app.userRegistrations.sendConfirmation(toEmail: email)
            guard let safeConf = conf else { XCTFail("could not retrieve email confirmation token"); return }
            emailPassClient.confirmUser(withToken: safeConf.token,
                                        withTokenID: safeConf.tokenID
                ) { _ in
                self.stitchAppClient.auth.login(
                    withCredential: UserPasswordCredential(withUsername: email, withPassword: password)
                ) { result in
                    switch result {
                    case .success(let user):
                        completionHandler(user)
                    case .failure:
                        XCTFail("Failed to log in with username/password provider")
                    }
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
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
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
            case .failure:
                XCTFail("unexpected error")
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    func testCustomLogin() throws {
        let jwt = encode(JWT.Algorithm.hs256(
            "abcdefghijklmnopqrstuvwxyz1234567890".data(using: .utf8)!)
        ) { (builder: ClaimSetBuilder) in
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
            case .failure:
                XCTFail("unexpected error")
            }

            exp1.fulfill()
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
                case .failure:
                    XCTFail("unexpected error")
                }

                exp2.fulfill()
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
            case .failure:
                XCTFail("unexpected error")
            }

            exp1.fulfill()
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
            case .failure:
                XCTFail("unexpected error")
            }

            exp2.fulfill()
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
            case .failure:
                XCTFail("unexpected error")
            }

            exp1.fulfill()
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
            withCredential: UserPasswordCredential.init(withUsername: "stitch@10gen.com", withPassword: "password")
        ) { result in
            switch result {
            case .success(let linkedUser):
                XCTAssertEqual(anonUser.id, linkedUser.id)
                self.verifyBasicAuthStorageInfo(loggedIn: true, expectedProviderType: StitchProviderType.userPassword)
                XCTAssertEqual(linkedUser.profile.identities.count, 2)
            case .failure:
                XCTFail("unexpected error")
            }

            exp4.fulfill()
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        logoutAndCheckStorage()
    }

    func testCallFunction() {
        _ = self.harness.addTestFunction()

        let exp1 = expectation(description: "logged in anonymously")
        stitchAppClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }

            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let exp2 = expectation(description: "called function successfully")
        let randomInt = Int(arc4random_uniform(10000)) // temporary until BSON bug is fixed
        stitchAppClient.callFunction(withName: "testFunction",
                                     withArgs: [randomInt, "hello"],
                                     withRequestTimeout: 5.0) { (result: StitchResult<Document>) in
                                        switch result {
                                        case .success(let doc):
                                            XCTAssertEqual(doc["stringValue"] as? String, "hello")

                                            guard let intValue = doc["intValue"] as? Int else {
                                                XCTFail("Int result missing in function return value")
                                                return
                                            }

                                            XCTAssertEqual(intValue, randomInt)
                                        case .failure:
                                            XCTFail("unexpected error")
                                        }

                                        exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "successfully errored out with a timeout when one was specified")
        stitchAppClient.callFunction(withName: "testFunction",
                                     withArgs: [randomInt, "hello"],
                                     withRequestTimeout: 0.00001) { result in
                                        switch result {
                                        case .success:
                                            XCTFail("timeout error expected")
                                        case .failure(let error):
                                            guard case .requestErrorFull(_, let errorCode) = error else {
                                                XCTFail("callFunction returned an incorrect error type")
                                                return
                                            }

                                            XCTAssertEqual(errorCode, .transportError)
                                        }

                                        exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)
    }

    func testCallFunctionRawValues() {
        _ = self.harness.addTestFunctionsRawValues()

        let exp1 = expectation(description: "logged in anonymously")
        stitchAppClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: defaultTimeoutSeconds)

        let exp2 = expectation(description: "called raw int function successfully")
        stitchAppClient.callFunction(withName: "testFunctionRawInt",
                                     withArgs: [], withRequestTimeout: 5.0) { (result: StitchResult<Int>) in
                                        switch result {
                                        case .success(let intResponse):
                                            XCTAssertEqual(intResponse, 42)
                                        case .failure:
                                            XCTFail("unexpected error")
                                        }

                                        exp2.fulfill()
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "called raw int function successfully")
        stitchAppClient.callFunction(withName: "testFunctionRawString",
                                     withArgs: [], withRequestTimeout: 5.0) { (result: StitchResult<String>) in
                                        switch result {
                                        case .success(let stringResponse):
                                            XCTAssertEqual(stringResponse, "hello world!")
                                        case .failure:
                                            XCTFail("unexpected error")
                                        }

                                        exp3.fulfill()
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "called raw array function successfully")
        stitchAppClient.callFunction(withName: "testFunctionRawArray",
                                     withArgs: [], withRequestTimeout: 5.0) { (result: StitchResult<[Int]>) in
                                        switch result {
                                        case .success(let arrayResponse):
                                            XCTAssertEqual(arrayResponse, [1, 2, 3])
                                        case .failure:
                                            XCTFail("unexpected error")
                                        }

                                        exp4.fulfill()
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        // Will not compile until BSONValue conforms to Decodable (SWIFT-104)
//        let exp5 = expectation(description: "called raw heterogenous array function successfully")
//        stitchAppClient.callFunction(
//            withName: "testFunctionRawHeterogenousArray",
//            withArgs: [], withRequestTimeout: 5.0) { (arrayResponse: StitchResult<[BSONValue]>) in
//                switch result {
//                case .success(let arrayResponse):
//                    XCTAssertEqual(arrayResponse, [1, "hello", 3])
//                case .failure:
//                    XCTFail()
//                }
//
//                exp5.fulfill()
//        }
//        wait(for: [exp5], timeout: defaultTimeoutSeconds)
    }
}
