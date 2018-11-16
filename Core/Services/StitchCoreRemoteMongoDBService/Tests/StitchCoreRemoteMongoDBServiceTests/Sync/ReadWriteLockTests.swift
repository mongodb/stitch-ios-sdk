import Foundation
import XCTest
@testable import StitchCoreRemoteMongoDBService

class ReadWriteLockTests: XCTestCase {
    func testSingleReader() {
        let l = ReadWriteLock()

        XCTAssertTrue(l.tryReadLock())

        XCTAssertTrue(l.unlock())
    }

    func testSingleWriter() {
        let l = ReadWriteLock()

        XCTAssertTrue(l.tryWriteLock())

        XCTAssertTrue(l.unlock())
    }

    func testMultipleReaders_SameThread() {
        let l = ReadWriteLock()

        XCTAssertTrue(l.tryReadLock())
        XCTAssertTrue(l.tryReadLock())

        XCTAssertTrue(l.unlock())
        XCTAssertTrue(l.unlock())
    }

    func testMultipleWriters_SameThread() {
        let l = ReadWriteLock()

        XCTAssertTrue(l.tryWriteLock())
        XCTAssertFalse(l.tryWriteLock())

        XCTAssertTrue(l.unlock())
        XCTAssertTrue(l.unlock())
    }

    func testReadWrite_SameThread() {
        let l = ReadWriteLock()

        XCTAssertNotNil( l )
        XCTAssertTrue( l.tryReadLock() )
        XCTAssertFalse( l.tryWriteLock() )

        XCTAssertTrue(l.unlock())
        XCTAssertTrue(l.unlock())
    }

    func testWriteRead_SameThread() {
        let l = ReadWriteLock()

        XCTAssertNotNil( l )
        XCTAssertTrue( l.tryWriteLock() )
        XCTAssertFalse( l.tryReadLock() )

        XCTAssertTrue(l.unlock())
        XCTAssertTrue(l.unlock())
    }

    func testMultipleReaders_DifferentThreads() {
        let l = ReadWriteLock()
        var b = false

        l.readLock()

        let sem = DispatchSemaphore(value: 0)
        let _ = Thread {
            b = l.tryReadLock()

            if (b) {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()
        XCTAssertTrue(b)
        XCTAssertTrue(l.unlock())
    }

    func testMultipleWriters_DifferentThreads() {
        let l = ReadWriteLock()
        var b = false

        XCTAssertNotNil(l)

        l.writeLock()

        var sem = DispatchSemaphore(value: 0)
        let _ = Thread {
            b = l.tryWriteLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()

        XCTAssertFalse(b)

        l.unlock()

        sem = DispatchSemaphore(value: 0)
        let _ = Thread {
            b = l.tryWriteLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()
        XCTAssertTrue(b)
    }

    func testReadWrite_DifferentThreads() {
        let l = ReadWriteLock()
        var b = false

        XCTAssertNotNil(l)

        l.readLock()

        var sem = DispatchSemaphore.init(value: 0)
        let _ = Thread {
            b = l.tryWriteLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()

        XCTAssertFalse(b)

        l.unlock()

        sem = DispatchSemaphore.init(value: 0)
        let _ = Thread {
            b = l.tryWriteLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()
        XCTAssertTrue(b)
    }

    func testWriteRead_DifferentThreads() {
        let l = ReadWriteLock()
        var b = false

        l.writeLock()

        var sem = DispatchSemaphore.init(value: 0)
        let _ = Thread {
            b = l.tryReadLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()

        XCTAssertFalse(b)

        l.unlock()

        sem = DispatchSemaphore.init(value: 0)
        let _ = Thread {
            b = l.tryReadLock()

            if b {
                l.unlock()
            }
            sem.signal()
            }.start()
        sem.wait()

        XCTAssertTrue(b)
    }
}
