import Foundation
import XCTest
import StitchCore
import StitchCoreAdminClient
import StitchIOSCoreTestUtils
import StitchFCMService

class FCMServicePushClientIntTests: BaseStitchIntTestCocoaTouch {
    private let fcmSenderIDProp = "test.stitch.fcmSenderID"
    private let fcmAPIKeyProp = "test.stitch.fcmAPIKey"
    
    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))
    
    private lazy var fcmSenderID: String? = pList?[fcmSenderIDProp] as? String
    private lazy var fcmAPIKey: String? = pList?[fcmAPIKeyProp] as? String
    
    override func setUp() {
        super.setUp()
        
        guard fcmSenderID != nil && fcmSenderID != "<your-sender-id>",
            fcmAPIKey != nil && fcmAPIKey != "<your-api-key>" else {
                XCTFail("No FCM sender ID or API key in properties; failing test. See README for more details.")
                return
        }
    }
    
    func testRegister() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "gcm",
            withName: "gcm",
            withConfig: ServiceConfigs.fcm(name: "gcm", senderID: fcmSenderID!, apiKey: fcmAPIKey!)
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
        
        let fcmPush = client.push.client(forFactory: FCMPushService.sharedFactory, withName: "gcm")
        
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
        fcmPush.deregister() { result in
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
        fcmPush.deregister() { result in
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
