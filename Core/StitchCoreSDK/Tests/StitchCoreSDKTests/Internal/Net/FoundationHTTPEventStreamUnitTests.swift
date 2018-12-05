import Foundation
import XCTest
@testable import StitchCoreSDK

public class FoundationHTTPEventStreamUnitTests: XCTestCase {
    func testReadLine() {
        let eventStream = FoundationHTTPEventStream()

        let line1 = "They dined on mince and slices of quince,"
        let line2 = "Which they ate with a runcible spoon;"
        let line3 = "And hand in hand, on the edge of the sand,"
        let line4 = "They danced by the light of the moon."
        let string = """
        \(line1)
        \(line2)
        \(line3)
        \(line4)
        """

        // inject data into stream
        eventStream.urlSession(URLSession(),
                               dataTask: URLSessionDataTask(),
                               didReceive: string.data(using: .utf8)!)

        XCTAssertEqual(eventStream.readLine(), line1)
        XCTAssertEqual(eventStream.readLine(), line2)
        XCTAssertEqual(eventStream.readLine(), line3)
        XCTAssertEqual(eventStream.readLine(), line4)
        XCTAssertEqual(eventStream.readLine(), "")
    }

    func testNextEvent() throws {
        let odds = "never tell me the odds"
        let treason = "it's treason then"

        let dataOdds = "data: \(odds)"
        let dataTreason = "data: \(treason)"

        let data = """
        \n
        \(dataOdds)\n
        \(dataTreason)\n\n
        """.data(using: .utf8)!

        let stream = FoundationHTTPEventStream()
        stream.urlSession(URLSession(),
                          dataTask: URLSessionDataTask(),
                          didReceive: data)

        // mock open the stream
        stream.urlSession(URLSession(),
                          dataTask: URLSessionDataTask(),
                          didReceive: HTTPURLResponse.init(url: URL.init(fileURLWithPath: ""),
                                                           statusCode: 200,
                                                           httpVersion: nil,
                                                           headerFields: nil)!,
                          completionHandler: { _ in })

        XCTAssertEqual(odds, try stream.nextEvent().data)

        XCTAssertEqual(treason, try stream.nextEvent().data)

        stream.close()
    }
}
