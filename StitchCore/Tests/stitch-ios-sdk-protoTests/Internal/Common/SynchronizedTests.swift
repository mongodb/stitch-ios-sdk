// swiftlint:disable force_try
import XCTest
@testable import StitchCore

class SynchronizedTests: XCTestCase {
    struct Counter {
        fileprivate var value = 0
    }

    func testSync() throws {
        let queue = OperationQueue()
        var counter = Counter()

        let sema = DispatchSemaphore(value: 0)
        Thread {
            for i in 0 ..< 100 {
                queue.addOperation {
                    try! sync(self) {
                        let value = counter.value
                        if i % 2 == 0 {
                            usleep(50)
                        }
                        counter.value += 1
                        XCTAssert(value == counter.value - 1)
                    }
                    if i == 99 { sema.signal() }
                }
            }
        }.start()
        sema.wait()
    }
}
