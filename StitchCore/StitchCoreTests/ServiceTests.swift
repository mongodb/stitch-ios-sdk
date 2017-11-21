//
//  ServiceTests.swift
//  StitchCoreTests
//
//  Created by Jason Flax on 11/16/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//
import XCTest
import Foundation
import StitchLogger
import ExtendedJson
@testable import StitchCore

class ServiceTests: XCTestCase {
    let client = StitchClient(appId: "test-uybga")
    let epProvider = EmailPasswordAuthProvider(username: "stitch@mongodb.com",
                                               password: "stitchuser")

    override func setUp() {
        super.setUp()

        LogManager.minimumLogLevel = LogLevel.debug
    }

    func testTwilio() throws {
        let exp = self.expectation(description: "twilio sent")
        self.client.anonymousAuth().then { _ -> StitchTask<Undefined> in
            return self.client.services.twilio(name: "tw1").send(from: "+15005550006",
                                                                 to: "+19088392649",
                                                                 body: "Fee-fi-fo-fum")
        }.then { (_: Undefined) in
            exp.fulfill()
        }.catch { err in
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }

        self.wait(for: [exp], timeout: 10)
    }

    func testGcm() throws {
        let exp = self.expectation(description: "gcm")

        self.client.anonymousAuth().then { _ -> StitchTask<AvailablePushProviders> in
            return self.client.getPushProviders()
        }.then { (providers: AvailablePushProviders) -> PushClient in
            guard let gcm = providers.gcm else {
                XCTFail("\(providers) does not contain gcm")
                exp.fulfill()
                throw StitchError.responseParsingFailed(reason: "\(providers)")
            }

            return try self.client.push.forProvider(info: gcm)
        }.then { (gcm: PushClient) -> StitchTask<Void> in
            return gcm.registerToken(token: "000000000").then {
                gcm.deregister()
            }
        }.then { _ in
            exp.fulfill()
        }.catch {
            XCTFail($0.localizedDescription)
            exp.fulfill()
        }

        self.wait(for: [exp], timeout: 10)
    }
}
