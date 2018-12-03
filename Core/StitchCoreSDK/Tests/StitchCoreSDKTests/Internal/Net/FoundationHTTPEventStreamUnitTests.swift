import Foundation
import XCTest
@testable import StitchCoreSDK

public class FoundationHTTPEventStreamUnitTests: XCTestCase {
    func testReadLine() {
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

        XCTAssertTrue(string.contains("\n"))
        let inputStream = InputStream.init(data: string.data(using: .utf8)!)
        inputStream.open()
        let eventStream = FoundationHTTPEventStream.init(inputStream: inputStream)
        XCTAssertEqual(eventStream.readLine(), line1)
        XCTAssertEqual(eventStream.readLine(), line2)
        XCTAssertEqual(eventStream.readLine(), line3)
        XCTAssertEqual(eventStream.readLine(), line4)
    }

    func testNextEvent() throws {
        let odds = "never tell me the odds"
        let treason = "it's treason then"

        let dataOdds = "data: \(odds)"
        let dataTreason = "data: \(treason)"

        let inputStream = InputStream.init(data: """
        \(dataOdds)
        \(dataTreason)\n
        """.data(using: .utf8)!)
        inputStream.open()
        let stream = FoundationHTTPEventStream.init(inputStream: inputStream)

        XCTAssertTrue(stream.isOpen)

        XCTAssertEqual(dataOdds, stream.readLine())

        XCTAssertTrue(stream.isOpen)

        XCTAssertEqual(treason, try stream.nextEvent().data)

        stream.close()
    }
}
