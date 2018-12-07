import XCTest
@testable import Swifter
@testable import StitchCoreSDK

class FoundationHTTPTransportIntTests: StitchXCTestCase {
    let responseBody = "foo"
    let headerKey = "bar"
    let headerValue = "baz"
    lazy var headers = [self.headerKey: self.headerValue]

    let getEndpoint = "/get"
    let notGetEndpoint = "/notget"
    let badRequestEndpoint = "/badreq"
    let streamEndpoint = "/sse"

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

        let builder = RequestBuilder()
            .with(method: .get)
            .with(url: "badURL")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: self.headers)

        XCTAssertThrowsError(
            try transport.roundTrip(request: builder.build())
        ) { error in
            XCTAssertEqual(error.localizedDescription, "unsupported URL")
        }

        builder.with(url: "\(self.baseURL)\(self.getEndpoint)")

        var response = try transport.roundTrip(request: builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))

        builder.with(url: "\(self.baseURL)\(self.notGetEndpoint)")
        builder.with(method: .post)
        builder.with(body: self.responseBody.data(using: .utf8))

        response = try transport.roundTrip(request: builder.build())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, self.responseBody.data(using: .utf8))

        builder.with(url: "\(self.baseURL)\(self.badRequestEndpoint)")

        response = try transport.roundTrip(request: builder.build())
        XCTAssertEqual(response.statusCode, 400)

        builder.with(url: "http://localhost:9000/notreal")

        XCTAssertThrowsError(
            try transport.roundTrip(request: builder.build())
        ) { error in
            XCTAssertEqual(error.localizedDescription, "Could not connect to the server.")
        }
    }

    func testStream() throws {
        var lines = [
            "'And oh, what a terrible country it is!",
            "Nothing but thick jungles infested by the most dangerous beasts in the entire world –",
            "hornswogglers and snozzwangers and those terrible wicked whangdoodles.",
            "A whangdoodle would eat ten Oompa-Loompas for breakfast and come galloping back for a second helping.'"
        ]

        self.server[self.streamEndpoint] = { req -> HttpResponse in
            return HttpResponse.raw(
                200,
                "OK", [
                "Content-Type" : "text/event-stream",
                "Cache-Control" : "no-cache",
                "Connection" : "keep-alive"
            ]) { writer in
                var _lines = Array(lines)
                while !_lines.isEmpty {
                    try! writer.write("data: \(_lines.removeFirst())\n\n".data(using: .utf8)!)
                }
            }
        }

        let transport = FoundationHTTPTransport()

        let builder = RequestBuilder()
            .with(method: .get)
            .with(url: "\(self.baseURL)\(self.streamEndpoint)")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: self.headers)

        class WonkaDelegate: SSEStreamDelegate {
            let lineExp: XCTestExpectation
            let closeExp: XCTestExpectation
            var events = [RawSSE]()

            init(_ xcTestCase: XCTestCase) {
                lineExp = xcTestCase.expectation(description: "lines should be equal")
                closeExp = xcTestCase.expectation(description: "stream should close")
            }

            override func on(newEvent event: RawSSE) {
                events.append(event)
                if events.count >= 4 {
                    lineExp.fulfill()
                }
            }

            override func on(stateChangedFor state: SSEStreamState) {
                if state == .closed {
                    closeExp.fulfill()
                }
            }
        }

        let delegate = WonkaDelegate(self)
        let eventStream = try transport.stream(request: builder.build(), delegate: delegate)

        wait(for: [delegate.lineExp], timeout: 10)

        eventStream.close()
        
        wait(for: [delegate.closeExp], timeout: 10)

        for i in 0 ..< 4 {
            print(delegate.events[i].rawData)
            print(lines[i])
            XCTAssertEqual(delegate.events[i].rawData, lines[i])
        }
    }
}
