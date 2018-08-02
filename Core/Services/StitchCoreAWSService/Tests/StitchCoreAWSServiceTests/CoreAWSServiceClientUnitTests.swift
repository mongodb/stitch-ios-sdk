import XCTest
import MockUtils
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
@testable import StitchCoreAWSService

final class CoreAWSServiceClientUnitTests: XCTestCase {
    func testExecute() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreAWSServiceClient(withService: service)
        
        let expectedService = "ses"
        let expectedAction = "send"
        let expectedRegion = "us-east-1"
        let expectedArguments: Document = ["hi": "hello"]
        
        let request = try AWSRequestBuilder()
            .with(service: expectedService)
            .with(action: expectedAction)
            .with(region: expectedRegion)
            .with(arguments: expectedArguments)
            .build()
        
        let response: Document = ["email": "sent"]
        
        service.callFunctionWithDecodingMock.doReturn(
            result: response,
            forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        let result: Document = try client.execute(request: request)
        
        XCTAssertEqual(response, result)
        
        var (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("execute", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "aws_service": expectedService,
            "aws_action": expectedAction,
            "aws_arguments": expectedArguments,
            "aws_region": expectedRegion
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // second request
        
        let request2 = try AWSRequestBuilder()
            .with(service: expectedService)
            .with(action: expectedAction)
            .build()
        
        let result2: Document = try client.execute(request: request2)
        XCTAssertEqual(response, result2)
        
        (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("execute", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs2: Document = [
            "aws_service": expectedService,
            "aws_action": expectedAction,
            "aws_arguments": Document.init()
        ]
        
        XCTAssertEqual(expectedArgs2, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.execute(request: request)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
        
    }
}
