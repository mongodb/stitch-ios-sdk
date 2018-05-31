import XCTest
import MockUtils
import MongoSwift
import StitchCore
@testable import StitchCoreServicesTwilio

final class MockCoreStitchService: CoreStitchService {
    public var callFunctionInternalMock = FunctionMockUnitThreeArgs<Void, String, [BsonValue], TimeInterval?>()
    func callFunctionInternal(withName name: String,
                              withArgs args: [BsonValue],
                              withRequestTimeout requestTimeout: TimeInterval?) throws {
        return try callFunctionInternalMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout)
    }
    
    public var callFunctionInternalWithDecodingMock =
        FunctionMockUnitThreeArgs<Decodable, String, [BsonValue], TimeInterval?>()
    func callFunctionInternal<T>(withName name: String,
                                 withArgs args: [BsonValue],
                                 withRequestTimeout requestTimeout: TimeInterval?) throws -> T where T : Decodable {
        if let result = try callFunctionInternalWithDecodingMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout) as? T {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}

class StitchCoreServicesTwilioTests: XCTestCase {
    func testSendMessage() throws {
        let service = MockCoreStitchService()
        let client = CoreTwilioServiceClient(withService: service)
        
        let to = "+15558509552"
        let from = "+15558675309"
        let body = "I've got your number"
        
        try client.sendMessageInternal(to: to, from: from, body: body)
        
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
            try client.sendMessageInternal(to: to, from: from, body: body)
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
        
        try client.sendMessageInternal(to: to, from: from, body: body, mediaURL: mediaUrl)
        
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
            try client.sendMessageInternal(to: to, from: from, body: body, mediaURL: mediaUrl)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
