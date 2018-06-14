import Foundation
import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
@testable import StitchCoreFCMService

final class CoreFCMServiceClientUnitTests: XCTestCase {
    func testSendMessage() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreFCMServiceClient.init(withServiceClient: service)
        
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
        let timeToLive: Int64 = 10000000000
        
        let fullRequest = FCMSendMessageRequestBuilder()
            .with(collapseKey: collapseKey)
            .with(contentAvailable: contentAvailable)
            .with(data: data)
            .with(mutableContent: mutableContent)
            .with(notification: notification)
            .with(priority: priority)
            .with(timeToLive: timeToLive)
            .build()
        
        let failureDetails = [
            FCMSendMessageResultFailureDetail.init(index: 1, error: "hello", userID: "world"),
            FCMSendMessageResultFailureDetail.init(index: 2, error: "woo", userID: "foo")
        ]
        
        let result = FCMSendMessageResult.init(successes: 4, failures: 2, failureDetails: failureDetails)
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: result,
            forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        // to single recipient
        
        let to = "who"
        XCTAssertEqual(result, try client.sendMessage(to: to, withRequest: fullRequest))
        
        var (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedNotif: Document = [
            "title": title,
            "body": body,
            "sound": sound,
            "clickAction": clickAction,
            "bodyLocKey": bodyLocKey,
            "bodyLocArgs": bodyLocArgs,
            "titleLocKey": titleLocKey,
            "titleLocArgs": titleLocArgs,
            "icon": icon,
            "tag": tag,
            "color": color,
            "badge": badge
        ]
        
        let baseExpectedArgs: Document = [
            "priority": priority.rawValue,
            "collapseKey": collapseKey,
            "contentAvailable": contentAvailable,
            "mutableContent": mutableContent,
            "timeToLive": timeToLive,
            "data": data,
            "notification": expectedNotif
        ]
        
        var toExpectedArgs = baseExpectedArgs
        toExpectedArgs["to"] = to
        XCTAssertEqual(toExpectedArgs, funcArgsArg[0] as? Document)
        
        // registration tokens
        let registrationTokens = ["one", "two"]
        XCTAssertEqual(
            result,
            try client.sendMessage(toRegistrationTokens: registrationTokens, withRequest: fullRequest)
        )
        
        XCTAssertEqual(2, service.callFunctionInternalWithDecodingMock.capturedInvocations.count)
        (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        var registrationTokensExpectedArgs = baseExpectedArgs
        registrationTokensExpectedArgs["registrationTokens"] = registrationTokens
        XCTAssertEqual(registrationTokensExpectedArgs, funcArgsArg[0] as? Document)
        
        // user ids
        let userIDs = ["two", "three"]
        XCTAssertEqual(result, try client.sendMessage(toUserIDs: userIDs, withRequest: fullRequest))
        
        XCTAssertEqual(3, service.callFunctionInternalWithDecodingMock.capturedInvocations.count)
        (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        var userIDsExpectedArgs = baseExpectedArgs
        userIDsExpectedArgs["userIds"] = userIDs
        XCTAssertEqual(userIDsExpectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        do {
            _ = try client.sendMessage(to: "blah", withRequest: fullRequest)
            XCTFail("request did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
