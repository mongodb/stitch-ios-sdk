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
    let testParams: TestParams
    let transport: FoundationInstrumentedHTTPTransport
    let harness: SyncPerformanceIntTestHarness

    let joiner = ThrowingCallbackJoiner()
    let streamJoiner = StreamJoiner()

    required init(harness: SyncPerformanceIntTestHarness,
                  testParams: TestParams,
                  transport: FoundationInstrumentedHTTPTransport) throws {
        self.harness = harness
        self.transport = transport
        self.testParams = testParams

        dbName = harness.stitchTestDbName
        collName = harness.stitchTestCollName
        client = harness.outputClient
        mongoClient = harness.outputMongoClient
        coll = mongoClient.db(dbName).collection(collName)
        userId = client.auth.currentUser?.id ?? "No User"

        coll.sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        coll.sync.proxy.dataSynchronizer.stop() // Failing here occaisonally
    }

    func tearDown() throws {
        client.callFunction(withName: "deleteAllAsSystemUser", withArgs: [], joiner.capture())
        let _: Any? = try joiner.value()

        if coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate != nil {
            coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate.stop()
        }

        // swiftlint:disable force_cast
        try CoreLocalMongoDBService.shared.localInstances.forEach { client in
            do {
                try client.listDatabases().forEach {
                    try? client.db($0["name"] as! String).drop()
                }
            } catch {
                throw "Could not drop databases in ProductionPerformanceTestContext.teardown()"
            }
        }
        // swiftlint:enable force_cast
    }
}
