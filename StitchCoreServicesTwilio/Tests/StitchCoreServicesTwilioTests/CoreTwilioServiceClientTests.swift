import XCTest
import MongoSwift
import StitchCore
import StitchCoreMocks
@testable import StitchCoreServicesTwilio

class CoreTwilioServiceClientTests: XCTestCase {
    func testSendMessage() throws {
        let service = MockCoreStitchService()
        let client = CoreTwilioServiceClient(withService: service)
        
        let to = "+15558509552"
        let from = "+15558675309"
        let body = "I've got your number"
        
        try client.sendMessage(to: to, from: from, body: body)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalMock.capturedInvocations.first!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = ["to": to, "from": from, "body": body]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalMock.doThrow(
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
        let service = MockCoreStitchService()
        let client = CoreTwilioServiceClient(withService: service)
        
        let to = "+15558509552"
        let from = "+15558675309"
        let body = "I've got your number"
        let mediaUrl = "https://jpegs.com/myjpeg.gif.png"
        
        try client.sendMessage(to: to, from: from, body: body, mediaURL: mediaUrl)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalMock.capturedInvocations.first!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = ["to": to, "from": from, "body": body, "mediaUrl": mediaUrl]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            try client.sendMessage(to: to, from: from, body: body, mediaURL: mediaUrl)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
