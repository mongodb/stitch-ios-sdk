import XCTest
@testable import StitchCoreHTTPService

final class HTTPRequestUnitTests: XCTestCase {
    
    func testBuilder() throws {
        XCTAssertThrowsError(try HTTPRequestBuilder().build()) { error in
            XCTAssertTrue(error is HTTPRequestBuilderError)
        }
        
        XCTAssertThrowsError(try HTTPRequestBuilder().with(url: "http://aol.com").build()) { error in
            XCTAssertTrue(error is HTTPRequestBuilderError)
        }
        
        XCTAssertThrowsError(try HTTPRequestBuilder().with(method: .delete).build()) { error in
            XCTAssertTrue(error is HTTPRequestBuilderError)
        }
        
        // Minimum satisfied
        let expectedURL = "http://aol.com"
        let expectedMethod = HTTPMethod.delete
        
        let request = try HTTPRequestBuilder().with(url: expectedURL).with(method: expectedMethod).build()
        
        XCTAssertEqual(expectedURL, request.url)
        XCTAssertEqual(expectedMethod, request.method)
        
        XCTAssertNil(request.authURL)
        XCTAssertNil(request.body)
        XCTAssertNil(request.cookies)
        XCTAssertNil(request.encodeBodyAsJSON)
        XCTAssertNil(request.followRedirects)
        XCTAssertNil(request.form)
        XCTAssertNil(request.headers)
        
        // Full params
        let expectedAuthURL = "https://username@password:woo.com";
        let expectedBody = "hello world!".data(using: .utf8)!
        let expectedCookies: [String: String] = ["some":"cookie"]
        let expectedForm: [String: String] = ["some": "form"]
        let expectedHeaders: [String: [String]] = ["some": ["head", "ers"]]
        
        let fullRequest = try HTTPRequestBuilder()
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
        
        XCTAssertEqual(expectedURL, fullRequest.url)
        XCTAssertEqual(expectedMethod, fullRequest.method)
        
        XCTAssertEqual(expectedAuthURL, fullRequest.authURL!)
        XCTAssertEqual(expectedBody, fullRequest.body!)
        XCTAssertEqual(expectedCookies, fullRequest.cookies!)
        XCTAssertEqual(false, fullRequest.encodeBodyAsJSON!)
        XCTAssertEqual(true, fullRequest.followRedirects!)
        XCTAssertEqual(expectedForm, fullRequest.form!)
        
        // Workaround since `XCTAssertEqual(expectedHeaders, fullRequest.headers!)` does not compile on Evergreen
        expectedHeaders.forEach { (key, value) in
            XCTAssertTrue(fullRequest.headers!.keys.contains(key))
            XCTAssertEqual(value, fullRequest.headers![key]!)
        }
    }
}
