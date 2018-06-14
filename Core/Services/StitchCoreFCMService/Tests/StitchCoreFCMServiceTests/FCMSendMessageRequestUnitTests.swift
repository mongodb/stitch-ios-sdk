import Foundation
import XCTest
import MongoSwift
@testable import StitchCoreFCMService

final class FCMSendMessageRequestUnitTests: XCTestCase {
    func testBuilder() throws {
        // minimum satisfied
        let request = FCMSendMessageRequestBuilder().build()
        
        XCTAssertEqual(.normal, request.priority)
        XCTAssertNil(request.collapseKey)
        XCTAssertNil(request.contentAvailable)
        XCTAssertNil(request.data)
        XCTAssertNil(request.mutableContent)
        XCTAssertNil(request.notification)
        XCTAssertNil(request.timeToLive)
        
        // fully specified
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
        
        XCTAssertEqual(collapseKey, fullRequest.collapseKey)
        XCTAssertEqual(contentAvailable, fullRequest.contentAvailable)
        XCTAssertEqual(data, fullRequest.data)
        XCTAssertEqual(mutableContent, fullRequest.mutableContent)
        
        guard let fullRequestNotification = fullRequest.notification else {
            XCTFail("fullRequest.notification unexpectedly nil")
            return
        }
        
        XCTAssertEqual(badge, fullRequestNotification.badge)
        XCTAssertEqual(body, fullRequestNotification.body)
        XCTAssertEqual(bodyLocArgs, fullRequestNotification.bodyLocArgs)
        XCTAssertEqual(bodyLocKey, fullRequestNotification.bodyLocKey)
        XCTAssertEqual(clickAction, fullRequestNotification.clickAction)
        XCTAssertEqual(color, fullRequestNotification.color)
        XCTAssertEqual(icon, fullRequestNotification.icon)
        XCTAssertEqual(sound, fullRequestNotification.sound)
        XCTAssertEqual(tag, fullRequestNotification.tag)
        XCTAssertEqual(title, fullRequestNotification.title)
        XCTAssertEqual(titleLocArgs, fullRequestNotification.titleLocArgs)
        XCTAssertEqual(titleLocKey, fullRequestNotification.titleLocKey)
        
        XCTAssertEqual(priority, fullRequest.priority)
        XCTAssertEqual(timeToLive, fullRequest.timeToLive)
    }
}
