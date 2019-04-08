// swiftlint:disable force_try
import Foundation
@testable import StitchCoreSDK
import StitchCoreTestUtils
@testable import Swifter
import XCTest

let testDefaultRequestTimeout: TimeInterval = 15.0

class FoundationInstrumentedTransportIntTests: StitchXCTestCase {
    func testGetBytesTracked() throws {
        let transport = FoundationInstrumentedHTTPTransport()

        XCTAssertEqual(transport.bytesDownloaded, 0)
        XCTAssertEqual(transport.bytesUploaded, 0)

        let reqBuilder = RequestBuilder()
            .with(method: .get)
            .with(url: "http://httpbin.org/get")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["some": "header"])

        let response = try transport.roundTrip(request: reqBuilder.build())

        XCTAssertEqual(response.statusCode, 200)

        XCTAssertTrue(500 < transport.bytesDownloaded && transport.bytesDownloaded < 600)
        XCTAssertTrue(50 < transport.bytesUploaded && transport.bytesUploaded < 60)
    }

    func testPostBytesTracked() throws {
        let transport = FoundationInstrumentedHTTPTransport()

        XCTAssertEqual(transport.bytesDownloaded, 0)
        XCTAssertEqual(transport.bytesUploaded, 0)

        let reqBuilder = RequestBuilder()
            .with(method: .post)
            .with(url: "http://httpbin.org/post")
            .with(timeout: testDefaultRequestTimeout)
            .with(body: "hello! I am a body! 😀".data(using: .utf8))
            .with(headers: ["some": "header"])

        let response = try transport.roundTrip(request: reqBuilder.build())

        XCTAssertEqual(response.statusCode, 200)

        XCTAssertTrue(700 < transport.bytesDownloaded && transport.bytesDownloaded < 800)
        XCTAssertTrue(70 < transport.bytesUploaded && transport.bytesUploaded < 80)
    }

    class TestStreamDelegate: SSEStreamDelegate {
        let instrumentedTransport: FoundationInstrumentedHTTPTransport
        let testCase: XCTestCase

        var lineExp: XCTestExpectation
        var closeExp: XCTestExpectation

        var eventCount = 0

        init(_ xcTestCase: XCTestCase, transport: FoundationInstrumentedHTTPTransport) {
            testCase = xcTestCase
            lineExp = xcTestCase.expectation(description: "the lines in the stream should be counted")
            closeExp = xcTestCase.expectation(description: "stream should close")
            instrumentedTransport = transport
        }

        override func on(newEvent event: RawSSE) {
            eventCount += 1

            if eventCount >= 4 {
                lineExp.fulfill()
            }
        }

        override func on(stateChangedFor state: SSEStreamState) {
            if state == .closed {
                closeExp.fulfill()
            }
        }

        internal func reset() {
            lineExp = testCase.expectation(description: "the lines in the stream should be counted")
            closeExp = testCase.expectation(description: "stream should close")
            eventCount = 0
        }
    }

    let streamEndpoint = "/sse"
    let streamLines = [
        "'And oh, what a terrible country it is!",
        "Nothing but thick jungles infested by the most" +
        "dangerous beasts in the entire world –",
        "hornswogglers and snozzwangers and those terrible" +
        "wicked whangdoodles.",
        "A whangdoodle would eat ten Oompa-Loompas for " +
        "breakfast and come galloping back for a second helping.'"
    ]

    func testStreamBytesTracked() throws {
        self.server[streamEndpoint] = { req -> HttpResponse in
            return HttpResponse.raw(
                200,
                "OK", [
                    "Content-Type": "text/event-stream",
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive"
            ]) { writer in
                var linesArr = Array(self.streamLines)
                while !linesArr.isEmpty {
                    try! writer.write("data: \(linesArr.removeFirst())\n\n".data(using: .utf8)!)
                }
            }
        }

        let transport = FoundationInstrumentedHTTPTransport()

        let builder = RequestBuilder()
            .with(method: .get)
            .with(url: "\(self.baseURL)\(streamEndpoint)")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["foo": "bar"])

        let delegate = TestStreamDelegate(self, transport: transport)
        let eventStream = try transport.stream(request: builder.build(), delegate: delegate)

        wait(for: [delegate.lineExp], timeout: 10)

        XCTAssertTrue(400 < transport.bytesDownloaded && transport.bytesDownloaded < 500)
        XCTAssertTrue(50 < transport.bytesUploaded && transport.bytesUploaded < 60)

        eventStream.close()

        wait(for: [delegate.closeExp], timeout: 10)
    }

    func testBytesTrackedForMultipleRequests() throws {
        // Do the first request
        let transport = FoundationInstrumentedHTTPTransport()

        XCTAssertEqual(transport.bytesDownloaded, 0)
        XCTAssertEqual(transport.bytesUploaded, 0)

        let reqBuilder = RequestBuilder()
            .with(method: .get)
            .with(url: "http://httpbin.org/get")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["some": "header"])

        var response = try transport.roundTrip(request: reqBuilder.build())

        XCTAssertEqual(response.statusCode, 200)

        XCTAssertTrue(500 < transport.bytesDownloaded && transport.bytesDownloaded < 600)
        XCTAssertTrue(50 < transport.bytesUploaded && transport.bytesUploaded < 60)

        // Do the second request
        response = try transport.roundTrip(request: reqBuilder.build())

        XCTAssertEqual(response.statusCode, 200)

        // Make sure the results are additive
        XCTAssertTrue(1000 < transport.bytesDownloaded && transport.bytesDownloaded < 1200)
        XCTAssertTrue(100 < transport.bytesUploaded && transport.bytesUploaded < 120)
    }

    func testStreamBytesTrackedForMultipleRequests() throws {
        // Do the first request
        self.server[streamEndpoint] = { req -> HttpResponse in
            return HttpResponse.raw(
                200,
                "OK", [
                    "Content-Type": "text/event-stream",
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive"
            ]) { writer in
                var linesArr = Array(self.streamLines)
                while !linesArr.isEmpty {
                    try! writer.write("data: \(linesArr.removeFirst())\n\n".data(using: .utf8)!)
                }
            }
        }

        let transport = FoundationInstrumentedHTTPTransport()

        let builder = RequestBuilder()
            .with(method: .get)
            .with(url: "\(self.baseURL)\(streamEndpoint)")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["foo": "bar"])

        let delegate = TestStreamDelegate(self, transport: transport)
        var eventStream = try transport.stream(request: builder.build(), delegate: delegate)

        wait(for: [delegate.lineExp], timeout: 10)

        XCTAssertTrue(400 < transport.bytesDownloaded && transport.bytesDownloaded < 500)
        XCTAssertTrue(50 < transport.bytesUploaded && transport.bytesUploaded < 60)

        eventStream.close()

        wait(for: [delegate.closeExp], timeout: 10)

        // Do the second request
        delegate.reset()

        eventStream = try transport.stream(request: builder.build(), delegate: delegate)

        wait(for: [delegate.lineExp], timeout: 10)

        // Make sure the results are additive
        XCTAssertTrue(800 < transport.bytesDownloaded && transport.bytesDownloaded < 1000)
        XCTAssertTrue(100 < transport.bytesUploaded && transport.bytesUploaded < 120)

        eventStream.close()

        wait(for: [delegate.closeExp], timeout: 10)
    }

    func testBytesTrackedForMixedRequestTypes() throws {
        let transport = FoundationInstrumentedHTTPTransport()

        XCTAssertEqual(transport.bytesDownloaded, 0)
        XCTAssertEqual(transport.bytesUploaded, 0)

        // Do normal request
        let reqBuilder = RequestBuilder()
            .with(method: .get)
            .with(url: "http://httpbin.org/get")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["some": "header"])

        let response = try transport.roundTrip(request: reqBuilder.build())

        XCTAssertEqual(response.statusCode, 200)

        XCTAssertTrue(500 < transport.bytesDownloaded && transport.bytesDownloaded < 600)
        XCTAssertTrue(50 < transport.bytesUploaded && transport.bytesUploaded < 60)

        // Do stream request
        self.server[streamEndpoint] = { req -> HttpResponse in
            return HttpResponse.raw(
                200,
                "OK", [
                    "Content-Type": "text/event-stream",
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive"
            ]) { writer in
                var linesArr = Array(self.streamLines)
                while !linesArr.isEmpty {
                    try! writer.write("data: \(linesArr.removeFirst())\n\n".data(using: .utf8)!)
                }
            }
        }

        let streamReqBuilder = RequestBuilder()
            .with(method: .get)
            .with(url: "\(self.baseURL)\(streamEndpoint)")
            .with(timeout: testDefaultRequestTimeout)
            .with(headers: ["foo": "bar"])

        let delegate = TestStreamDelegate(self, transport: transport)
        let eventStream = try transport.stream(request: streamReqBuilder.build(), delegate: delegate)

        wait(for: [delegate.lineExp], timeout: 10)

        // Make sure the results are additive
        XCTAssertTrue(900 < transport.bytesDownloaded && transport.bytesDownloaded < 1100)
        XCTAssertTrue(100 < transport.bytesUploaded && transport.bytesUploaded < 120)

        eventStream.close()

        wait(for: [delegate.closeExp], timeout: 10)
    }
}
