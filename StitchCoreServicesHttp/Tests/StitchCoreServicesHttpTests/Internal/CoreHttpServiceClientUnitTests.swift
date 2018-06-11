import XCTest
import MongoSwift
import StitchCore
import StitchCoreMocks
@testable import StitchCoreServicesHttp

final class CoreHttpServiceClientUnitTests: XCTestCase {
    func testExecute() throws {
        let service = MockCoreStitchService()
        let client = CoreHttpServiceClient.init(withService: service)
        
        let expectedUrl = "http://aol.com"
        let expectedMethod = HttpMethod.delete
        let expectedAuthUrl = "https://username@password:woo.com";
        let expectedBody = "hello world!".data(using: .utf8)!
        let expectedCookies: [String: String] = ["some":"cookie"]
        let expectedForm: [String: String] = ["some": "form"]
        let expectedHeaders: [String: [String]] = ["some": ["head", "ers"]]
        
        let request = try HttpRequestBuilder()
            .with(url: expectedUrl)
            .with(authUrl: expectedAuthUrl)
            .with(method: expectedMethod)
            .with(body: expectedBody)
            .with(cookies: expectedCookies)
            .with(encodeBodyAsJson: false)
            .with(followRedirects: true)
            .with(form: expectedForm)
            .with(headers: expectedHeaders)
            .build()
        
        let response = HttpResponse.init(
            status: "OK",
            statusCode: 200,
            contentLength: 304,
            headers: expectedHeaders,
            cookies: [:],
            body: "response body".data(using: .utf8)
        )
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: response, forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        _ = try client.execute(request: request)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("delete", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "url": expectedUrl,
            "authUrl": expectedAuthUrl,
            "headers": try BsonEncoder().encode(expectedHeaders),
            "cookies": try BsonEncoder().encode(expectedCookies),
            "body": Binary.init(data: expectedBody, subtype: .binary),
            "encodeBodyAsJSON": false,
            "form": try BsonEncoder().encode(expectedForm),
            "followRedirects": true
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
            _ = try client.execute(request: request)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
