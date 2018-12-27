import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
@testable import StitchCoreTwilioService

class CoreTwilioServiceClientUnitTests: XCTestCase {
    func testSendMessage() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreTwilioServiceClient(withService: service)

        let to = "+15558509552"
        let from = "+15558675309"
        let body = "I've got your number"

        try client.sendMessage(to: to, from: from, body: body)

        let (funcNameArg, funcArgsArg, _) = service.callFunctionMock.capturedInvocations.first!

        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = ["to": to, "from": from, "body": body]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            try client.sendMessage(to: to, from: from, body: body)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }

    func testSendMessageWithMedia() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreTwilioServiceClient(withService: service)

        let to = "+15558509552"
        let from = "+15558675309"
        let body = "I've got your number"
        let mediaURL = "https://jpegs.com/myjpeg.gif.png"

        try client.sendMessage(to: to, from: from, body: body, mediaURL: mediaURL)

        let (funcNameArg, funcArgsArg, _) = service.callFunctionMock.capturedInvocations.first!

        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)

        let expectedArgs: Document = ["to": to, "from": from, "body": body, "mediaUrl": mediaURL]

        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)

        // should pass along errors
        service.callFunctionMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )

        do {
            try client.sendMessage(to: to, from: from, body: body, mediaURL: mediaURL)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
