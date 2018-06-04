import XCTest
import MongoSwift
import StitchCore
import StitchCoreMocks
@testable import StitchCoreServicesAwsSes

final class CoreAwsSesServiceClientTests: XCTestCase {
    func testSendEmail() throws {
        let service = MockCoreStitchService()
        let client = CoreAwsSesServiceClient(withService: service)
        
        let to = "eliot@10gen.com"
        let from = "dwight@10gen.com"
        let subject = "Hello"
        let body = "again friend"
        
        let expectedMessageId = "yourMessageId"
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: AwsSesSendResult.init(messageId: expectedMessageId),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        let result = try client.sendEmail(toAddress: to, fromAddress: from, subject: subject, body: body)
        
        XCTAssertEqual(expectedMessageId, result.messageId)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("send", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "toAddress": to,
            "fromAddress": from,
            "subject": subject,
            "body": body
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.sendEmail(toAddress: to, fromAddress: from, subject: subject, body: body)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
