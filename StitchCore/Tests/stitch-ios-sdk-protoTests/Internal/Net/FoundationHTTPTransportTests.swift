import XCTest
import Swifter
@testable import StitchCore

class FoundationHTTPTransportTests: StitchXCTestCase {
    let responseBody = "foo"
    let headerKey = "bar"
    let headerValue = "baz"
    lazy var headers = [self.headerKey: self.headerValue]

    let getEndpoint = "/get"
    let notGetEndpoint = "/notget"
    let badRequestEndpoint = "/badreq"

    override func setUp() {
        self.server[self.getEndpoint] = { request in
            XCTAssertEqual(request.headers[self.headerKey],
                           self.headers[self.headerKey])
            return .ok(.text(self.responseBody))
        }
        self.server[self.notGetEndpoint] = { request in
            XCTAssertEqual(request.headers[self.headerKey],
                           self.headers[self.headerKey])
            let data = Data(request.body)
            return .ok(.text(String.init(data: data, encoding: .utf8)!))
        }
        self.server[self.badRequestEndpoint] = { request in
            XCTAssertEqual(request.headers[self.headerKey],
                           self.headers[self.headerKey])
            return .badRequest(.text("bad request"))
        }

        super.setUp()
    }

    func testRoundTrip() throws {
        let transport = FoundationHTTPTransport()
        var builder = Request.TBuilder {
            $0.method = .get
            $0.url = "badURL"
            $0.headers = self.headers
        }

        XCTAssertThrowsError(
            try transport.roundTrip(request: builder.build()),
            StitchErrorCode.invalidURL.rawValue,
            { _ in }
        )

        builder.url = "\(self.baseURL)\(self.getEndpoint)"

        var response = try transport.roundTrip(request: builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))

        builder.url = "\(self.baseURL)\(self.notGetEndpoint)"
        builder.method = .post
        builder.body = self.responseBody.data(using: .utf8)

        response = try transport.roundTrip(request: builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))

        builder.url = "\(self.baseURL)\(self.badRequestEndpoint)"

        response = try transport.roundTrip(request: builder.build())
        XCTAssertEqual(response.statusCode, 400)

        builder.url = "http://localhost:9000/notreal"
        XCTAssertThrowsError(
            try transport.roundTrip(request: builder.build()),
            StitchErrorCode.unknown.rawValue,
            { _ in }
        )
    }
}

