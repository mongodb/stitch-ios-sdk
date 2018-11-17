import Foundation
import StitchCoreSDK
import StitchCoreSDKMocks
import XCTest
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class DataSynchronizerUnitTests: XCMongoMobileTestCase {
    let mockServiceClient = MockCoreStitchServiceClient.init()
    class TestNetworkMonitor: NetworkMonitor {
        var networkStateListeners = [NetworkStateListener]()

        func isConnected() -> Bool {
            return true
        }

        func add(networkStateListener listener: NetworkStateListener) {
            self.networkStateListeners.append(listener)
        }

        func remove(networkStateListener listener: NetworkStateListener) {
            if let index = self.networkStateListeners.firstIndex(where: { $0 === listener }) {
                self.networkStateListeners.remove(at: index)
            }
        }
    }

    class TestAuthMonitor: AuthMonitor {
        func isLoggedIn() -> Bool {
            return true
        }
    }

    class TestConflictHandler: ConflictHandler {
        typealias DocumentT = Document
        func resolveConflict(documentId: BSONValue,
                             localEvent: ChangeEvent<Document>,
                             remoteEvent: ChangeEvent<Document>) throws -> Document? {
            return remoteEvent.fullDocument
        }
    }

    class TestErrorListener: ErrorListener {
        func on(error: Error, forDocumentId documentId: BSONValue?) {
        }
    }

    class TestEventListener: ChangeEventListener {
        typealias DocumentT = Document
        func onEvent(documentId: BSONValue,
                     event: ChangeEvent<Document>) {
        }
    }

    let instanceKey = ObjectId()
    lazy var dataSynchronizer = try! DataSynchronizer.init(
        instanceKey: instanceKey.oid,
        service: MockCoreStitchServiceClient.init(),
        localClient: XCMongoMobileTestCase.client,
        remoteClient: CoreRemoteMongoClient.init(withService: mockServiceClient),
        networkMonitor: TestNetworkMonitor(),
        authMonitor: TestAuthMonitor())
    let namespace = MongoNamespace.init(databaseName: "db", collectionName: "coll")

    override func tearDown() {
        try? XCMongoMobileTestCase.client.db("sync_config" + instanceKey.oid).drop()
    }

    func testStart_Stop() {
        XCTAssertFalse(dataSynchronizer.isRunning)
        
        dataSynchronizer.start()

        XCTAssertTrue(dataSynchronizer.isRunning)

        dataSynchronizer.stop()

        XCTAssertFalse(dataSynchronizer.isRunning)
    }

    func testSync_SyncedIds_Desync() {
        let ids = [ObjectId(), ObjectId()]

        dataSynchronizer.sync(ids: ids, in: namespace)
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       dataSynchronizer.syncedIds(in: namespace))

        dataSynchronizer.desync(ids: ids, in: namespace)
        XCTAssertEqual(Set(),
                       dataSynchronizer.syncedIds(in: namespace))
    }

    func testConfigure_ReloadConfig() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertTrue(dataSynchronizer.isRunning)

        try dataSynchronizer.reloadConfig()

        XCTAssertFalse(dataSynchronizer.isRunning)
    }
}
