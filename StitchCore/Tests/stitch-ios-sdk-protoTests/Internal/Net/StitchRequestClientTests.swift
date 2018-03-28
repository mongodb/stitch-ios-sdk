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

        super.setUp()
    }

    func testDoRequest() throws {
        let stitchRequestClient = StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                           transport: FoundationHTTPTransport())

        var builder = StitchRequestImpl.TBuilder {
            $0.path = self.badRequestEndpoint
            $0.method = .get
        }

        XCTAssertThrowsError(try stitchRequestClient.doRequest(builder.build()))

        builder.path = self.getEndpoint

        let response = try stitchRequestClient.doRequest(builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))
    }

    func testDoJSONRequestRaw() throws {
        let stitchRequestClient = StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                           transport: FoundationHTTPTransport())

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
