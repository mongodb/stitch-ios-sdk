import Foundation
import XCTest
import MongoSwift
import StitchCoreAdminClient
import StitchIOSCoreTestUtils
import StitchFCMService

class FCMServiceClientIntTests: BaseStitchIntTestCocoaTouch {
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
    
    func testSendMessage() throws {
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
        
        let collapseKey = "one"
        let contentAvailable = true
        let data: Document = ["hello": "world"]
        let mutableContent = true
        
        let badge = "myBadge"
        let body = "hellllo"
        let bodyLocArgs = "woo"
        let bodyLocKey = "hoo"
        let clickAction = "how"
        let color = "are"
        let icon = "you"
        let sound = "doing"
        let tag = "today"
        let title = "my"
        let titleLocArgs = "good"
        let titleLocKey = "friend"
        
        let notification = FCMSendMessageNotificationBuilder()
            .with(badge: badge)
            .with(body: body)
            .with(bodyLocArgs: bodyLocArgs)
            .with(bodyLocKey: bodyLocKey)
            .with(clickAction: clickAction)
            .with(color: color)
            .with(icon: icon)
            .with(sound: sound)
            .with(tag: tag)
            .with(title: title)
            .with(titleLocArgs: titleLocArgs)
            .with(titleLocKey: titleLocKey)
            .build()
        
        let priority = FCMSendMessagePriority.high
        let timeToLive: Int64 = 2419200
        
        let fullRequest = FCMSendMessageRequestBuilder()
            .with(collapseKey: collapseKey)
            .with(contentAvailable: contentAvailable)
            .with(data: data)
            .with(mutableContent: mutableContent)
            .with(notification: notification)
            .with(priority: priority)
            .with(timeToLive: timeToLive)
            .build()
        
//        // Sending to a invalid registration should fail
//        val to = "who"
//        var result = Tasks.await(fcm.sendMessageTo(to, fullRequest))
//        assertEquals(0, result.successes)
//        assertEquals(1, result.failures)
//        assertEquals(1, result.failureDetails.size)
//        assertEquals(0, result.failureDetails[0].index)
//        assertEquals("InvalidRegistration", result.failureDetails[0].error)
//        Assert.assertNull(result.failureDetails[0].userId)
//        
//        // Sending to a topic should work
//        val topic = "/topics/what"
//        result = Tasks.await(fcm.sendMessageTo(topic, fullRequest))
//        assertEquals(1, result.successes)
//        assertEquals(0, result.failures)
//        assertEquals(0, result.failureDetails.size)
//
//        result = Tasks.await(fcm.sendMessageToRegistrationTokens(listOf("one", "two"), fullRequest))
//        assertEquals(0, result.successes)
//        assertEquals(2, result.failures)
//        assertEquals(2, result.failureDetails.size)
//        assertEquals(0, result.failureDetails[0].index)
//        assertEquals("InvalidRegistration", result.failureDetails[0].error)
//        Assert.assertNull(result.failureDetails[0].userId)
//        assertEquals(1, result.failureDetails[1].index)
//        assertEquals("InvalidRegistration", result.failureDetails[1].error)
//        Assert.assertNull(result.failureDetails[1].userId)
//
//        // Any invalid parameters should fail
//        val badRequest = FcmSendMessageRequest.Builder()
//            .withTimeToLive(100000000000000L)
//            .build()
//        try {
//        Tasks.await(fcm.sendMessageTo(to, badRequest))
//        fail()
//        } catch (ex: ExecutionException) {
//        Assert.assertTrue(ex.cause is StitchServiceException)
//        val svcEx = ex.cause as StitchServiceException
//        assertEquals(StitchServiceErrorCode.INVALID_PARAMETER, svcEx.errorCode)
//        }
        
        
    }
}
