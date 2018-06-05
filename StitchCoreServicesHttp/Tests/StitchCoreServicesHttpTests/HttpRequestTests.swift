import XCTest
@testable import StitchCoreServicesHttp

final class HttpRequestTests: XCTestCase {
    
    func testBuilder() throws {
        XCTAssertThrowsError(try HttpRequestBuilder().build()) { error in
            XCTAssertTrue(error is HttpRequestBuilderError)
        }
        
        XCTAssertThrowsError(try HttpRequestBuilder().with(url: "http://aol.com").build()) { error in
            XCTAssertTrue(error is HttpRequestBuilderError)
        }
        
        XCTAssertThrowsError(try HttpRequestBuilder().with(method: .delete).build()) { error in
            XCTAssertTrue(error is HttpRequestBuilderError)
        }
        
        // Minimum satisfied
        let expectedUrl = "http://aol.com"
        let expectedMethod = HttpMethod.delete
        
        let request = try HttpRequestBuilder().with(url: expectedUrl).with(method: expectedMethod).build()
        
        XCTAssertEqual(expectedUrl, request.url)
        XCTAssertEqual(expectedMethod, request.method)
        
        XCTAssertNil(request.authUrl)
        XCTAssertNil(request.body)
        XCTAssertNil(request.cookies)
        XCTAssertNil(request.encodeBodyAsJson)
        XCTAssertNil(request.followRedirects)
        XCTAssertNil(request.form)
        XCTAssertNil(request.headers)
        
        // Full params
        let expectedAuthUrl = "https://username@password:woo.com";
        let expectedBody = "hello world!".data(using: .utf8)!
        let expectedCookies: [String: String] = ["some":"cookie"]
        let expectedForm: [String: String] = ["some": "form"]
        let expectedHeaders: [String: [String]] = ["some": ["head", "ers"]]
        
        let fullRequest = try HttpRequestBuilder()
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
        
        XCTAssertEqual(expectedUrl, fullRequest.url)
        XCTAssertEqual(expectedMethod, fullRequest.method)
        XCTAssertEqual(expectedAuthUrl, fullRequest.authUrl)
        XCTAssertEqual(expectedBody, fullRequest.body)
        XCTAssertEqual(expectedCookies, fullRequest.cookies)
        XCTAssertEqual(false, fullRequest.encodeBodyAsJson)
        XCTAssertEqual(true, fullRequest.followRedirects)
        XCTAssertEqual(expectedForm, fullRequest.form)
        XCTAssertEqual(expectedHeaders, fullRequest.headers)
    }
    
}

