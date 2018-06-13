import XCTest
import MockUtils
import MongoSwift
@testable import StitchCoreSDK
import StitchCoreSDKMocks

class StitchRequestClientUnitTests: StitchXCTestCase {
    
    private struct UnrelatedError: Error { }
    private struct MockTimeoutError: Error { }

    func testDoRequest() throws {
        let domain = "http://domain.com"
        let transport = MockTransport()
        let stitchRequestClient = StitchRequestClientImpl.init(
            baseURL: domain,
            transport: transport,
            defaultRequestTimeout: 1.5
        )

        // A bad response should throw an exception
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: [:], body: nil),
            forArg: .any
        )
        
        let path = "/path"
        let builder = StitchRequestBuilder().with(path: path).with(method: .get)
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "should throw a Stitch service exeption"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(_, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
        }
        
        let actualRequest = transport.mockRoundTrip.capturedInvocations.first!
        
        let expectedRequest = try RequestBuilder()
            .with(method: .get)
            .with(url: "\(domain)\(path)")
            .with(timeout: 1.5)
            .build()
        
        XCTAssertEqual(expectedRequest, actualRequest)

        transport.mockRoundTrip.clearInvocations()
        transport.mockRoundTrip.clearStubs()

        // A normal response should be able to be decoded
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 200,
                                  headers: [ : ],
                                  body: "{\"hello\": \"world\", \"a\": 42}".data(using: .utf8)),
            forArg: .any
        )
        let response = try stitchRequestClient.doRequest(builder.build())
        
        XCTAssertEqual(response.statusCode, 200)
        
        // TODO: uncomment when SWIFT-104 is completed
        // let expected = ["hello": "world", "a": 42] as [String : BsonValue]
        // XCTAssertEqual(expected, BsonDecoder().decode([String: BsonValue].self, from: response.body!))
        
        transport.mockRoundTrip.clearStubs()
        
        // Error responses should be handled
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: [:], body: nil),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
            XCTAssertEqual(message, "received unexpected status code 500")
        }
        
        transport.mockRoundTrip.clearStubs()
        
        let headers = [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue]
        
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: headers, body: "whoops".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
            XCTAssertEqual(message, "whoops")
        }
    
        transport.mockRoundTrip.clearStubs()
        
        transport.mockRoundTrip.doReturn(
            result: Response.init(
                statusCode: 500,
                headers: headers,
                body: "{\"error\": \"bad\", \"error_code\": \"InvalidSession\"}".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.invalidSession)
            XCTAssertEqual(message, "bad")
        }
        
        // Handles round trip failing
        transport.mockRoundTrip.doThrow(error: UnrelatedError.init(), forArg: .any)
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "Stitch request client should wrap underlying errors in a StitchError.requestError")
        { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .requestError(let error, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchRequestErrorCode.transportError)
            XCTAssertTrue(error is UnrelatedError)
        }
    }
    
    func testDoJSONRequestWithDoc() throws {
        let domain = "http://domain.com"
        let transport = MockTransport()
        let stitchRequestClient = StitchRequestClientImpl.init(
            baseURL: domain,
            transport: transport,
            defaultRequestTimeout: 1.5
        )
        
        let path = "/path"
        let document = Document.init(["my": 24])
        let builder = StitchDocRequestBuilder()
            .with(path: path)
            .with(method: .get)
            .with(document: document)
            .with(method: .patch)
        
        // A bad response should throw an exception
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: [:], body: nil),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "should throw a Stitch service exeption"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(_, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
        }
        
        let actualRequest = transport.mockRoundTrip.capturedInvocations.first!
        
        let expectedRequest = try RequestBuilder()
            .with(method: .patch)
            .with(url: "\(domain)\(path)")
            .with(body: "{ \"my\" : { \"$numberInt\" : \"24\" } }".data(using: .utf8))
            .with(headers: [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue])
            .with(timeout: 1.5)
            .build()

        XCTAssertEqual(expectedRequest, actualRequest)
        
        transport.mockRoundTrip.clearStubs()
        
        // A normal response should be able to be decoded
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 200,
                                  headers: [ : ],
                                  body: "{\"hello\": \"world\", \"a\": 42}".data(using: .utf8)),
            forArg: .any
        )
        let response = try stitchRequestClient.doRequest(builder.build())
        
        XCTAssertEqual(response.statusCode, 200)
        
        // TODO: uncomment when SWIFT-104 is completed
        // let expected = ["hello": "world", "a": 42] as [String : BsonValue]
        // XCTAssertEqual(expected, BsonDecoder().decode([String: BsonValue].self, from: response.body!))
        
        transport.mockRoundTrip.clearStubs()
        
        // Error responses should be handled
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: [:], body: nil),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
            XCTAssertEqual(message, "received unexpected status code 500")
        }
        
        transport.mockRoundTrip.clearInvocations()
        transport.mockRoundTrip.clearStubs()
        
        let headers = [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue]
        
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 500, headers: headers, body: "whoops".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.unknown)
            XCTAssertEqual(message, "whoops")
        }
        
        transport.mockRoundTrip.clearInvocations()
        transport.mockRoundTrip.clearStubs()
        
        transport.mockRoundTrip.doReturn(
            result: Response.init(
                statusCode: 500,
                headers: headers,
                body: "{\"error\": \"bad\", \"error_code\": \"InvalidSession\"}".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.invalidSession)
            XCTAssertEqual(message, "bad")
        }
        
        // Handles round trup failing
        transport.mockRoundTrip.doThrow(error: UnrelatedError.init(), forArg: .any)
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "Stitch request client should wrap underlying errors in a StitchError.requestError")
        { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .requestError(let error, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchRequestErrorCode.transportError)
            XCTAssertTrue(error is UnrelatedError)
        }
    }
    
    func testHandleNonCanonicalHeaders() throws {
        let domain = "http://domain.com"
        let transport = MockTransport()
        let stitchRequestClient = StitchRequestClientImpl.init(
            baseURL: domain,
            transport: transport,
            defaultRequestTimeout: 1.5
        )
        
        let path = "/path"
        let builder = StitchRequestBuilder()
            .with(path: path)
            .with(method: .get)
        
        let nonCanonicalHeaders = [Headers.contentType.nonCanonical(): ContentTypes.applicationJSON.rawValue]
        
        // A bad response should throw an exception
        transport.mockRoundTrip.doReturn(
            result: Response.init(
                statusCode: 500,
                headers: nonCanonicalHeaders,
                body: "{\"error\": \"bad\", \"error_code\": \"InvalidSession\"}".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.invalidSession)
            XCTAssertEqual(message, "bad")
        }
        
        transport.mockRoundTrip.clearStubs()
        
        let canonicalHeaders = [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue]
        transport.mockRoundTrip.doReturn(
            result: Response.init(
                statusCode: 500,
                headers: canonicalHeaders,
                body: "{\"error\": \"bad\", \"error_code\": \"InvalidSession\"}".data(using: .utf8)),
            forArg: .any
        )
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.serviceError when a bad response is received"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .serviceError(let message, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchServiceErrorCode.invalidSession)
            XCTAssertEqual(message, "bad")
        }
    }
    
    func testDoRequestWithTimeout() throws {
        let domain = "http://domain.com"
        let transport = MockTransport()
        let stitchRequestClient = StitchRequestClientImpl.init(
            baseURL: domain,
            transport: transport,
            defaultRequestTimeout: 1.5
        )
        
        transport.mockRoundTrip.doThrow(
            error: MockTimeoutError.init(),
            forArg: Matcher<Request>.with(condition: { req -> Bool in
                return req.timeout == 3
            })
        )
        
        transport.mockRoundTrip.doReturn(
            result: Response.init(statusCode: 503, headers: [:], body: nil),
            forArg: Matcher<Request>.with(condition: { req -> Bool in
                return req.timeout != 3
            })
        )
        
        let builder = StitchRequestBuilder()
            .with(path: "/path")
            .with(method: .get)
            .with(timeout: 3)
        
        XCTAssertThrowsError(
            try stitchRequestClient.doRequest(builder.build()),
            "StitchRequestClient should throw StitchError.requestError when a timeout occurs"
        ) { error in
            let stitchErr = error as? StitchError
            XCTAssertNotNil(stitchErr)
            
            guard case .requestError(let underlyingError, let errorCode) = stitchErr! else {
                XCTFail("wrong StitchError error type was thrown")
                return
            }
            
            XCTAssertEqual(errorCode, StitchRequestErrorCode.transportError)
            XCTAssertTrue(underlyingError is MockTimeoutError)
        }
    }
}
