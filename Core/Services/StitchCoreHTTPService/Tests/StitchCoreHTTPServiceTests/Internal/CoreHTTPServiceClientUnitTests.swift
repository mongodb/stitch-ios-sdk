import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
@testable import StitchCoreHTTPService

final class CoreHTTPServiceClientUnitTests: XCTestCase {
    func testExecute() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreHTTPServiceClient.init(withService: service)
        
        let expectedURL = "http://aol.com"
        let expectedMethod = HTTPMethod.delete
        let expectedAuthURL = "https://username@password:woo.com";
        let expectedBody = "hello world!".data(using: .utf8)!
        let expectedCookies: [String: String] = ["some":"cookie"]
        let expectedForm: [String: String] = ["some": "form"]
        let expectedHeaders: [String: [String]] = ["some": ["head", "ers"]]
        
        let request = try HTTPRequestBuilder()
            .with(url: expectedURL)
            .with(authURL: expectedAuthURL)
            .with(method: expectedMethod)
            .with(body: expectedBody)
            .with(cookies: expectedCookies)
            .with(encodeBodyAsJSON: false)
            .with(followRedirects: true)
            .with(form: expectedForm)
            .with(headers: expectedHeaders)
            .build()
        
        let response = HTTPResponse.init(
            status: "OK",
            statusCode: 200,
            contentLength: 304,
            headers: expectedHeaders,
            cookies: [:],
            body: "response body".data(using: .utf8)
        )
        
        service.callFunctionWithDecodingMock.doReturn(
            result: response, forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        _ = try client.execute(request: request)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("delete", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "url": expectedURL,
            "authUrl": expectedAuthURL,
            "headers": try BSONEncoder().encode(expectedHeaders),
            "cookies": try BSONEncoder().encode(expectedCookies),
            "body": Binary.init(data: expectedBody, subtype: .binary),
            "encodeBodyAsJSON": false,
            "form": try BSONEncoder().encode(expectedForm),
            "followRedirects": true
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionWithDecodingMock.doThrow(
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
