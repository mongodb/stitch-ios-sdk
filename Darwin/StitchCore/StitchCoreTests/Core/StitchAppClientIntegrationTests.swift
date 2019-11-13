import Foundation
import XCTest
import StitchCoreSDK
import StitchCoreAdminClient
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
                                            guard case .requestError(_, let errorCode) = error else {
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

    func testCustomFunctionLogin() throws {
        _ = harness.createApp()

        let function = try harness.app.functions.create(data: FunctionCreator(
            name: "funkyAuth",
            source: """
            exports = function(payload) {
                return payload.id;
            };
            """,
            canEvaluate: nil,
            isPrivate: false
        ))

        _ = harness.addProvider(withConfig: ProviderConfigs.customFunction(authFunctionId: function.id!,
                                                                           authFunctionName: function.name!))

        let client = harness.stitchAppClient

        let id = "123abc"

        let exp = expectation(description: "login with FunctionalCredential works")
        var user: StitchUser!
        client?.auth.login(withCredential: FunctionCredential(payload: ["id": id])) {
            if case .success(let res) = $0 {
                user = res
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: defaultTimeoutSeconds)

        XCTAssertEqual(id, user.id)
        XCTAssertEqual(id, user.identities[0].id)

        XCTAssertEqual(FunctionAuthProvider.defaultName, user.loggedInProviderName)
        XCTAssertEqual(FunctionAuthProvider.type, user.loggedInProviderType.name)
        XCTAssertEqual(FunctionAuthProvider.type, user.identities[0].providerType)
        XCTAssertTrue(client!.auth.isLoggedIn)
    }

    func testCustomFunctionLoginFail() throws {
        _ = harness.createApp()

        let function = try harness.app.functions.create(data: FunctionCreator(
            name: "funkyAuth",
            source: """
            exports = function(payload) {
                return 0;
            };
            """,
            canEvaluate: nil,
            isPrivate: false
        ))

        _ = harness.addProvider(withConfig: ProviderConfigs.customFunction(authFunctionId: function.id!,
                                                                           authFunctionName: function.name!))

        let client = harness.stitchAppClient

        let exp = expectation(description: "login with FunctionalCredential works")
        client?.auth.login(withCredential: FunctionCredential(payload: ["id": "123abc"])) {
            if case .failure(_) = $0 {
                exp.fulfill()
            } else {
                XCTFail("Login with function credential should not have been successful")
            }
        }
        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    func testCallResetPasswordFunction() throws {
        _ = harness.createApp()

        let function = try harness.app.functions.create(data: FunctionCreator(
            name: "testResetPasswordFunction",
            source: """
            exports = function({email, password}, arg1, arg2) {
                if (arg1 == 0 && arg2 == 1) {
                    return { "status": "success" };
                } else {
                    return { "status": "fail" };
                }
            };
            """,
            canEvaluate: nil,
            isPrivate: false))

        _ = harness.addProvider(withConfig: ProviderConfigs.userpass(
            emailConfirmationURL: "http://emailConfirmURL.com",
            resetPasswordURL: "http://resetPasswordURL.com",
            confirmEmailSubject: "email subject",
            resetPasswordSubject: "password subject",
            runResetFunction: true,
            resetFunctionId: function.id!,
            resetFunctionName: function.name!))

        let client = harness.stitchAppClient!
        let userPassClient = client.auth.providerClient(fromFactory: userPasswordClientFactory)

        let email = "user@10gen.com"
        let password1 = "password1"
        let password2 = "password2"

        let exp = expectation(description: "user pass should register")
        userPassClient.register(withEmail: email, withPassword: password1) {
            switch $0 {
            case .success(_):
                exp.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp], timeout: defaultTimeoutSeconds)

        let conf = try harness.app.userRegistrations.sendConfirmation(toEmail: email)
        let exp2 = expectation(description: "user pass should confirm user")
        userPassClient.confirmUser(withToken: conf.token, withTokenID: conf.tokenID) {
            switch $0 {
            case .success(_):
                exp2.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp2], timeout: defaultTimeoutSeconds)

        let exp3 = expectation(description: "user pass should confirm user")
        client.auth.login(withCredential: UserPasswordCredential(withUsername: email, withPassword: password1)) {
            switch $0 {
            case .success(_):
                exp3.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp3], timeout: defaultTimeoutSeconds)

        let exp4 = expectation(description: "call reset password function should succeed")
        client.auth.providerClient(fromFactory: userPasswordClientFactory)
            .callResetPasswordFunction(email: email, password: password2, args: [
                0, 1
            ]) {
            switch $0 {
            case .success(_):
                exp4.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp4], timeout: defaultTimeoutSeconds)

        let exp5 = expectation(description: "logout should succeed")
        client.auth.logout() {
            switch $0 {
            case .success(_):
                exp5.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp5], timeout: defaultTimeoutSeconds)

        let exp6 = expectation(description: "logging in with new password should succeed")
        client.auth.login(withCredential: UserPasswordCredential(withUsername: email, withPassword: password2)) {
            switch $0 {
            case .success(_):
                exp6.fulfill()
            case .failure(let error):
                XCTFail(error.description)
            }
        }
        wait(for: [exp6], timeout: defaultTimeoutSeconds)
    }
}
