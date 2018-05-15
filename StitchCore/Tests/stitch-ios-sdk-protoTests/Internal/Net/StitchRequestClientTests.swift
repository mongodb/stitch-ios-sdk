import XCTest
import Swifter
import ExtendedJSON
@testable import StitchCore

class StitchRequestClientTests: StitchXCTestCase {
    let responseBody = "foo"
    let headerKey = "bar"
    let headerValue = "baz"
    lazy var headers = [self.headerKey: self.headerValue]

    let testDoc: Document = ["qux": "quux"]
    let getEndpoint = "/get"
    let notGetEndpoint = "/notget"
    let badRequestEndpoint = "/badreq"
    let timeoutEndpoint = "/timeout"

    override func setUp() {
        self.server[self.getEndpoint] = { request in
            return .ok(.text(self.responseBody))
        }
        self.server[self.notGetEndpoint] = { request in
            let data = Data(request.body)
            return .ok(.text(String.init(data: data, encoding: .utf8)!))
        }
        self.server[self.badRequestEndpoint] = { request in
            return .badRequest(.text("bad request"))
        }
        self.server[self.timeoutEndpoint] = { request in
            Thread.sleep(forTimeInterval: 20.0) // sleep for 20 seconds
            return .ok(.text("This response will not be seen since the client will timeout"))
        }

        super.setUp()
    }

    func testDoRequest() throws {
        let stitchRequestClient = StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                               transport: FoundationHTTPTransport(),
                                                               defaultRequestTimeout: testDefaultRequestTimeout)

        var builder = StitchRequestImpl.TBuilder {
            $0.path = self.badRequestEndpoint
            $0.method = .get
        }

        XCTAssertThrowsError(try stitchRequestClient.doRequest(builder.build())) { error in
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .serviceError = err else {
                    XCTFail("doRequest returned an incorrect error type")
                    return
                }
            }
        }

        builder.path = self.getEndpoint

        let response = try stitchRequestClient.doRequest(builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))
    }

    func testDoRequestWithTimeout() throws {
        let stitchRequestClient = StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                               transport: FoundationHTTPTransport(),
                                                               defaultRequestTimeout: testDefaultRequestTimeout)

        let builder = StitchRequestImpl.TBuilder {
            $0.path = self.timeoutEndpoint
            $0.method = .get
            $0.timeout = 3.0
        }

        XCTAssertThrowsError(try stitchRequestClient.doRequest(builder.build())) { error in
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .requestError(_, let errorCode) = err else {
                    XCTFail("doRequest returned an incorrect error type")
                    return
                }

                XCTAssertEqual(errorCode, .transportError)
            }
        }
    }

    func testDoJSONRequestRaw() throws {
        let stitchRequestClient = StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                               transport: FoundationHTTPTransport(),
                                                               defaultRequestTimeout: testDefaultRequestTimeout)

        var builder = StitchDocRequestBuilderImpl {
            $0.path = self.badRequestEndpoint
            $0.method = .post
        }

        XCTAssertThrowsError(try stitchRequestClient.doJSONRequestRaw(builder.build()))

        builder.path = self.notGetEndpoint
        builder.document = testDoc
        let response = try stitchRequestClient.doJSONRequestRaw(builder.build())

        XCTAssertEqual(response.statusCode, 200)

        XCTAssertEqual(try BSONDecoder().decode(Document.self, from: response.body!, hasSourceMap: false),
                       self.testDoc)
    }
}
