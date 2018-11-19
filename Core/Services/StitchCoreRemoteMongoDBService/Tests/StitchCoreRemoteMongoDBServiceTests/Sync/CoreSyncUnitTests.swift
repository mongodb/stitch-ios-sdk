import Foundation
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService
class CoreSyncUnitTests: XCMongoMobileTestCase {
    private let instanceKey = ObjectId()
    private let namespace = MongoNamespace.init(databaseName: "db", collectionName: "coll")

    private lazy var dataSynchronizer = DataSynchronizerUnitTests.dataSynchronizer(
        withInstanceKey: instanceKey
    )
    private lazy var coreSync = CoreSync<Document>.init(namespace: namespace,
                                                        dataSynchronizer: dataSynchronizer)

    override func tearDown() {
        try? XCMongoMobileTestCase.client.db("sync_config" + instanceKey.oid).drop()
    }
    
    func testConfigure() {
        XCTAssertFalse(dataSynchronizer.isConfigured)
        coreSync.configure(conflictHandler: DataSynchronizerUnitTests.TestConflictHandler(),
                           changeEventListener: DataSynchronizerUnitTests.TestEventListener(),
                           errorListener: DataSynchronizerUnitTests.TestErrorListener())
        XCTAssertTrue(dataSynchronizer.isConfigured)
        XCTAssertTrue(dataSynchronizer.isRunning)
    }

    func testSync_SyncedIds_Desync() {
        let ids = [ObjectId(), ObjectId()]

        coreSync.sync(ids: ids)
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       dataSynchronizer.syncedIds(in: namespace))
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       coreSync.syncedIds)

        coreSync.desync(ids: ids)
        XCTAssertEqual(Set(),
                       dataSynchronizer.syncedIds(in: namespace))
        XCTAssertEqual(Set(),
                       coreSync.syncedIds)
    }
}
