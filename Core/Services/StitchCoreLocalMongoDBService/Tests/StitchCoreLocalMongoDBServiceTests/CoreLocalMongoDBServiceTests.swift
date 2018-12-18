import XCTest
@testable import StitchCoreLocalMongoDBService

final class CoreLocalMongoDBServiceTests: XCTestCase {
    func testCoreLocalMongoDBService_localInstances() throws {
        let key = "key"
        let dbPath = FileManager().currentDirectoryPath
        var localClient1: MongoClient?
        var localClient2: MongoClient?
        var localClient3: MongoClient?

        try CoreLocalMongoDBService.shared.initialize()
        localClient1 = try CoreLocalMongoDBService.shared.client(withKey: key,
                                                                 withDBPath: dbPath)

        var sem = DispatchSemaphore.init(value: 0)
        Thread {
            localClient2 = try? CoreLocalMongoDBService.shared.client(withKey: key,
                                                                      withDBPath: dbPath)
            sem.signal()
        }.start()
        sem.wait()
        sem = DispatchSemaphore.init(value: 0)
        Thread {
            localClient3 = try? CoreLocalMongoDBService.shared.client(withKey: key,
                                                                      withDBPath: dbPath)
            sem.signal()
        }.start()
        sem.wait()

        XCTAssert(localClient1 !== localClient2)
        XCTAssert(localClient2 !== localClient3)
        XCTAssert(localClient1 !== localClient3)

        let localClient4 = try CoreLocalMongoDBService.shared.client(withKey: key,
                                                                     withDBPath: dbPath)

        XCTAssert(localClient1 === localClient4)
        CoreLocalMongoDBService.shared.close()
    }
}
