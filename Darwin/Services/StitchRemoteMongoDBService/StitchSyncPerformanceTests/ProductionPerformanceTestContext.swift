import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

class ProductionPerformanceTestContext: SyncPerformanceTestContext {
    let dbName: String
    let collName: String
    let userId: String
    let client: StitchAppClient
    let mongoClient: RemoteMongoClient
    let coll: RemoteMongoCollection<Document>
    let harness: SyncPerformanceIntTestHarness
    let joiner = ThrowingCallbackJoiner()
    let streamJoiner = StreamJoiner()

    required init(harness: SyncPerformanceIntTestHarness) throws {
        self.harness = harness

        dbName = harness.stitchTestDbName
        collName = harness.stitchTestCollName
        client = harness.outputClient
        mongoClient = try client.serviceClient(fromFactory: remoteMongoClientFactory,
                                               withName: "mongodb-atlas")
        coll = mongoClient.db(dbName).collection(collName)
        userId = client.auth.currentUser?.id ?? "No User"

        coll.sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        coll.sync.proxy.dataSynchronizer.stop()

        try self.clearLocalDB()
        try clearRemoteDB()
    }

    func tearDown() throws {
        if coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate != nil {
            coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate.stop()
        }

        try self.clearLocalDB()
        try clearRemoteDB()
    }

    func clearRemoteDB() throws {
        for _ in 0..<15 {
            do {
                client.callFunction(withName: "deleteAllAsSystemUser", withArgs: [], joiner.capture())
                // coll.deleteMany([:], joiner.capture())
                let _: Any? = try joiner.value()
                break
            } catch {
                harness.logMessage(message: "error deleting all documents \(error.localizedDescription)")
            }
        }
        let count = coll.count([:]) ?? 1
        if count != 0 {
            throw "Could not fully delete remote collection"
        }
    }
}
