import XCTest

import MongoSwift
import StitchCore
import StitchCoreAdminClient
import StitchCoreTestUtils_iOS
import StitchCoreServicesHttp
@testable import StitchCoreServicesHttp_iOS

class HTTPServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    func testExecute() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "http",
            withName: "http1",
            withConfig: ServiceConfigs.http(name: "http1")
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rules", actions: RuleActionsCreator.http(
                                get: true, post: false, put: false,
                                delete: true, patch: false, head: false)))
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _,_  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let httpClient = client.serviceClient(forFactory: HTTPService.sharedFactory, withName: "http1")
        
        // Specifying a request with a form AND body should fail.
        var badURL = "http://aol.com"
        let method = HTTPMethod.delete
        let body = "hello world".data(using: .utf8)!
        let cookies = ["bob": "barker"]
        let form: [String: String] = [:]
        let headers = ["myHeader": ["value1", "value2"]]
        
        var badRequest = try HTTPRequestBuilder()
            .with(url: badURL)
            .with(method: method)
            .with(body: body)
            .with(cookies: cookies)
            .with(form: form)
            .with(headers: headers)
            .build()
        
        let exp1 = expectation(description: "should not make request")
        httpClient.execute(request: badRequest) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        // Executing a request against a bad domain should fail
        badURL = "http://127.0.0.1:234"
        
        badRequest = try HTTPRequestBuilder()
            .with(url: badURL)
            .with(method: method)
            .with(body: body)
            .with(cookies: cookies)
            .with(headers: headers)
            .build()
        
        let exp2 = expectation(description: "should not make request")
        httpClient.execute(request: badRequest) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.httpError, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
        
        // A correctly specific request should succeed
        let goodRequest = try HTTPRequestBuilder()
            .with(url: "https://httpbin.org/delete")
            .with(method: method)
            .with(body: body)
            .with(cookies: cookies)
            .with(headers: headers)
            .build()
        
        let exp3 = expectation(description: "request should be successfully completed")
        var response: HTTPResponse!
        httpClient.execute(request: goodRequest) { (resp, _) in
            XCTAssertNotNil(resp)
            response = resp!
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 5.0)
        
        XCTAssertEqual("200 OK", response!.status)
        XCTAssertEqual(200, response!.statusCode)
        XCTAssertTrue(300 <= response!.contentLength && response!.contentLength <= 400)
        XCTAssertNotNil(response!.body)

        let dataDoc = try Document.init(fromJSON: response!.body!)
        
        let dataString: String = try dataDoc.get("data")
        XCTAssertEqual(String.init(data: body, encoding: .utf8)!, dataString)
        
        let headersDoc: Document = try dataDoc.get("headers")
        XCTAssertEqual("value1,value2", try headersDoc.get("Myheader"))
        XCTAssertEqual("bob=barker", try headersDoc.get("Cookie"))
    }
}
