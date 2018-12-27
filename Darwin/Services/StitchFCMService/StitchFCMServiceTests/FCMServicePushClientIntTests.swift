// swiftlint:disable function_body_length
import Foundation
import XCTest
import StitchCore
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchFCMService

let testFCMSenderID = TEST_FCM_SENDER_ID.isEmpty ?
    ProcessInfo.processInfo.environment["FCM_SENDER_ID"] : TEST_FCM_SENDER_ID
let testFCMAPIKey = TEST_FCM_API_KEY.isEmpty ?
    ProcessInfo.processInfo.environment["FCM_API_KEY"] : TEST_FCM_API_KEY

class FCMServicePushClientIntTests: BaseStitchIntTestCocoaTouch {
    override func setUp() {
        super.setUp()

        guard !(testFCMSenderID?.isEmpty ?? true),
            !(testFCMAPIKey?.isEmpty ?? true) else {
                XCTFail("No FCM_SENDER_ID or FCM_API_KEY in preprocessor macros; "
                        + "failing test. See README for more details.")
                return
        }
    }

    func testRegister() throws {
        let app = try self.createApp()
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "gcm",
            withName: "gcm",
            withConfig: ServiceConfigs.fcm(name: "gcm", senderID: testFCMSenderID!, apiKey: testFCMAPIKey!)
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.fcm(send: true)))

        let client = try self.appClient(forApp: app.0)

        var exp = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let fcmPush = client.push.client(fromFactory: fcmServicePushClientFactory, withName: "gcm")

        // can register and deregister multiple times
        exp = expectation(description: "can register once")
        fcmPush.register(withRegistrationToken: "hello") { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "can register again")
        fcmPush.register(withRegistrationToken: "hello") { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "can deregister once")
        fcmPush.deregister { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "can deregister again")
        fcmPush.deregister { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}
