import XCTest
import Foundation
import StitchLogger
import ExtendedJson
@testable import StitchCore

class ServiceTests: StitchTestCase {
    let epProvider = EmailPasswordAuthProvider(username: "stitch@mongodb.com",
                                                password: "stitchuser")

    func testTwilio() throws {
        XCTAssertNoThrow(try await(self.harness.add(
            serviceConfig: .twilio(name: "tw1",
                                   accountSid: "ACba1e2cfa6a2f1022f4ea426aaba0b36a",
                                   authToken: "7c285cb134e53244601db8cce7c8d06f"),
            withRules: Rule.init(name: "foo", actions: .twilio(send: true))
        )))

        try await(self.stitchClient.anonymousAuth())
        XCTAssertThrowsError(
            try await(TwilioService(client: self.stitchClient,
                                    name: "tw1").send(from: "+16097380962",
                                                      to: "+16097380962",
                                                      body: "Fee-fi-fo-fum"))
        )
    }

    /* TODO: Add GCM to Admin SDK
    func testGcm() throws {
        try await(self.stitchClient.login(withProvider: epProvider))
        let providers = try await(self.stitchClient.getPushProviders())
        guard let gcm = providers.gcm else {
            XCTFail("\(providers) does not contain gcm")
            return
        }

        let pushClient = try self.stitchClient.push.forProvider(info: gcm)
        try await(pushClient.registerToken(token: "1234567891011"))
        try await(pushClient.deregister())
    }*/ 
}
