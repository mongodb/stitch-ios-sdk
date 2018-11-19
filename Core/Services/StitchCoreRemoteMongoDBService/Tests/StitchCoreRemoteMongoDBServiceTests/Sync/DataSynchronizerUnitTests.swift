import Foundation
import StitchCoreSDK
import StitchCoreSDKMocks
import XCTest
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class DataSynchronizerUnitTests: XCMongoMobileTestCase {
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

    static func dataSynchronizer(withInstanceKey instanceKey: ObjectId) -> DataSynchronizer {
        let mockServiceClient = MockCoreStitchServiceClient.init()
        return try! DataSynchronizer.init(
            instanceKey: instanceKey.oid,
            service: mockServiceClient,
            localClient: XCMongoMobileTestCase.client,
            remoteClient: CoreRemoteMongoClient.init(withService: mockServiceClient),
            networkMonitor: TestNetworkMonitor(),
            authMonitor: TestAuthMonitor())
    }

    private let instanceKey = ObjectId()
    private let namespace = MongoNamespace.init(databaseName: "db", collectionName: "coll")
    private lazy var dataSynchronizer = DataSynchronizerUnitTests.dataSynchronizer(
        withInstanceKey: instanceKey
    )

    override func tearDown() {
        try? XCMongoMobileTestCase.client.db("sync_config" + instanceKey.oid).drop()
    }

    func testStart_Stop() {
        XCTAssertFalse(dataSynchronizer.isRunning)

        // dataSynchronizer should not start until configured
        dataSynchronizer.start()
        XCTAssertFalse(dataSynchronizer.isRunning)

        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())

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
