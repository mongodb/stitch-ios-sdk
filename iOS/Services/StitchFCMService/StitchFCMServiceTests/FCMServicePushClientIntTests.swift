import Foundation
import XCTest
import StitchIOSCoreTestUtils

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
    
    func testRegister() {
        fatalError("not yet implemented")
//        val app = createApp()
//        addProvider(app.second, ProviderConfigs.Anon)
//        val svc = addService(
//            app.second,
//            "gcm",
//            "gcm",
//            ServiceConfigs.Fcm(getFcmSenderId(), getFcmApiKey()))
//        addRule(svc.second, RuleCreator.Fcm("default", setOf(FcmActions.Send)))
//
//        val client = getAppClient(app.first)
//        Tasks.await(client.auth.loginWithCredential(AnonymousCredential()))
//
//        val fcm = client.push.getClient(FcmServicePushClient.Factory, "gcm")
//
//        // Can register and deregister multiple times.
//        Tasks.await(fcm.register("hello"))
//        Tasks.await(fcm.register("hello"))
//        Tasks.await(fcm.deregister())
//        Tasks.await(fcm.deregister())
    }
}
