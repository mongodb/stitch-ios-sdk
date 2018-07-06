import Foundation
import XCTest
import MongoSwift
import StitchCore
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchFCMService

class FCMServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    override func setUp() {
        super.setUp()
        
        guard !(testFCMSenderID?.isEmpty ?? true),
            !(testFCMAPIKey?.isEmpty ?? true) else {
                XCTFail("No FCM_SENDER_ID or FCM_API_KEY in preprocessor macros; failing test. See README for more details.")
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
        
        let fcm = client.serviceClient(fromFactory: fcmServiceClientFactory, withName: "gcm")
        
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

        let to = "who"
        
        exp = expectation(description: "sending to an invalid registration should fail")
        fcm.sendMessage(to: to, withRequest: fullRequest) { result in
            switch result {
            case .success(let fcmResult):
                XCTAssertEqual(0, fcmResult.successes)
                XCTAssertEqual(1, fcmResult.failures)
                XCTAssertEqual(1, fcmResult.failureDetails?.count)
                XCTAssertEqual(0, fcmResult.failureDetails![0].index)
                XCTAssertEqual("InvalidRegistration", fcmResult.failureDetails![0].error)
                XCTAssertNil(fcmResult.failureDetails![0].userID)
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        exp = expectation(description: "sending to a topic should work")
        let topic = "/topics/what"
        fcm.sendMessage(to: topic, withRequest: fullRequest) { result in
            switch result {
            case .success(let fcmResult):
                XCTAssertEqual(1, fcmResult.successes)
                XCTAssertEqual(0, fcmResult.failures)
                XCTAssertNil(fcmResult.failureDetails)
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        exp = expectation(description: "sending to invalid registration tokens should fail")
        fcm.sendMessage(toRegistrationTokens: ["one", "two"], withRequest: fullRequest) { result in
            switch result {
            case .success(let fcmResult):
                XCTAssertEqual(0, fcmResult.successes)
                XCTAssertEqual(2, fcmResult.failures)
                XCTAssertEqual(2, fcmResult.failureDetails?.count)
                XCTAssertEqual(0, fcmResult.failureDetails![0].index)
                XCTAssertEqual("InvalidRegistration", fcmResult.failureDetails![0].error)
                XCTAssertNil(fcmResult.failureDetails![0].userID)
                XCTAssertEqual(1, fcmResult.failureDetails![1].index)
                XCTAssertEqual("InvalidRegistration", fcmResult.failureDetails![1].error)
                XCTAssertNil(fcmResult.failureDetails![1].userID)
            case .failure:
                XCTFail("unexpected error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        
        exp = expectation(description: "any invalid parameters should fail")
        let badRequest = FCMSendMessageRequestBuilder()
            .with(timeToLive: 100000000000000)
            .build()
        
        fcm.sendMessage(to: "to", withRequest: badRequest) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let errorCode):
                    XCTAssertEqual(StitchServiceErrorCode.invalidParameter, errorCode)
                default:
                    print(error)
                    XCTFail("unexpected error type")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}
