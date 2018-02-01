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
    var client: StitchClient!
    let epProvider = EmailPasswordAuthProvider(username: "stitch@mongodb.com",
                                               password: "stitchuser")

    override func setUp() {
        super.setUp()

        LogManager.minimumLogLevel = LogLevel.debug
        let expectation = self.expectation(description: "should create stitchClient")
        StitchClientFactory.create(appId: "test-uybga").done {
            self.client = $0
            expectation.fulfill()
        }.cauterize()
        wait(for: [expectation], timeout: 10)
    }

    func testTwilio() throws {
        let exp = self.expectation(description: "twilio sent")
        self.client.anonymousAuth().then { _ in
            return TwilioService(client: self.client, name: "tw1").send(from: "+15005550006",
                                                                        to: "+19088392649",
                                                                        body: "Fee-fi-fo-fum")
        }.done { (_: Undefined) in
            exp.fulfill()
        }.catch { err in
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }

        self.wait(for: [exp], timeout: 10)
    }

    func testGcm() throws {
        let exp = self.expectation(description: "gcm")

        self.client.login(withProvider: epProvider).then { _ in
            return self.client.getPushProviders()
        }.flatMap { (providers: AvailablePushProviders) -> PushClient in
            guard let gcm = providers.gcm else {
                XCTFail("\(providers) does not contain gcm")
                exp.fulfill()
                throw StitchError.responseParsingFailed(reason: "\(providers)")
            }

            return try self.client.push.forProvider(info: gcm)
        }.flatMap { (gcm: PushClient) throws -> PushClient  in
            gcm.registerToken(token: "1234567891011")
            return gcm
        }.then {
            $0.deregister()
        }.done {
            exp.fulfill()
        }.catch {
            XCTFail($0.localizedDescription)
            exp.fulfill()
        }

        self.wait(for: [exp], timeout: 30)
    }
}
