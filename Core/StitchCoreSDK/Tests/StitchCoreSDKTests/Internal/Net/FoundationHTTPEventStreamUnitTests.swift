import Foundation
import XCTest
@testable import StitchCoreSDK

public class RawSSEStreamUnitTests: XCTestCase {
    func testDispatchEvents() throws {
        class PartialDelegate: SSEStreamDelegate {
            var lastEvent: RawSSE? = nil
            var semaphore = DispatchSemaphore(value: 0)

            override func on(newEvent event: RawSSE) {
                lastEvent = event
                semaphore.signal()
            }
        }

        let partialDelegate = PartialDelegate()
        let stream = RawSSEStream(partialDelegate)
        stream.state = .open
        let partialLine1 = "They dined on mince and slices of quince,"
        let partialLine2 = "Which they ate with a runcible spoon;"

        stream.dataBuffer.append("data: \(partialLine1)\n".data(using: .utf8)!)
        stream.dispatchEvents()
        XCTAssertNil(partialDelegate.lastEvent)
        stream.dataBuffer.append("data: \(partialLine2)\n\n".data(using: .utf8)!)

        stream.dispatchEvents()
        partialDelegate.semaphore.wait()
        XCTAssertEqual(partialDelegate.lastEvent?.rawData, partialLine1 + partialLine2)

        let partialLine3 = "And hand in hand, on the edge of the sand,"
        let partialLine4 = "They danced by the light of the moon."

        stream.dataBuffer.append("data: \(partialLine3)\ndata:\(partialLine4)\n\n".data(using: .utf8)!)
        stream.dispatchEvents()
        partialDelegate.semaphore.wait()
        XCTAssertEqual(partialDelegate.lastEvent?.rawData.split(separator: "\n"),
                       [Substring(partialLine3), Substring(partialLine4)])
    }
}
