import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

internal class SyncTestContext {
    let streamJoiner = StreamJoiner()
    let networkMonitor: NetworkMonitor
    let stitchClient: StitchAppClient
    let mongoClient: RemoteMongoClient

    private var currentColl: RemoteMongoCollection<Document>!
    private var currentSync: Sync<Document>!

    lazy var remoteCollAndSync = { () -> (RemoteMongoCollection<Document>, Sync<Document>) in
        let db = mongoClient.db(self.dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(self.collName)
        XCTAssertEqual(self.dbName, coll.databaseName)
        XCTAssertEqual(self.collName, coll.name)
        let sync = coll.sync
        sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        sync.proxy.dataSynchronizer.stop()

        self.currentColl = coll
        self.currentSync = sync
        return (coll, sync)
    }()

    private let dbName: String
    private let collName: String

    init(stitchClient: StitchAppClient,
         mongoClient: RemoteMongoClient,
         networkMonitor: NetworkMonitor,
         dbName: String,
         collName: String) {
        self.stitchClient = stitchClient
        self.mongoClient = mongoClient
        self.networkMonitor = networkMonitor
        self.dbName = dbName
        self.collName = collName
    }

    func waitForAllStreamsOpen() {
        while !currentSync.proxy.dataSynchronizer.allStreamsAreOpen {
            print("waiting for all streams to open before doing sync pass")
            sleep(1)
        }
    }

    func switchToUser(withId userId: String) throws {
        _ = try stitchClient.auth.switchToUser(withId: userId)
    }

    func removeUser(withId userId: String) throws {
        let joiner = CallbackJoiner.init()
        stitchClient.auth.removeUser(withId: userId, joiner.capture())

        // await the completion of the user removal
        let _: Any? = joiner.value()
    }

    func reloginUser2() throws {
        let joiner = CallbackJoiner.init()
        stitchClient.auth.login(
            withCredential: UserPasswordCredential(withUsername: "test1@10gen.com", withPassword: "hunter2"),
            joiner.capture()
        )

        // await the completion of the user login
        let _: Any? = joiner.value()
    }

    func streamAndSync() throws {
        if networkMonitor.state == .connected {
            // add the stream joiner as a delegate of the stream so we can wait for events
            if let iCSDel = currentSync.proxy

                .dataSynchronizer
                .instanceChangeStreamDelegate,
                let nsConfig = iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)] {
                nsConfig.add(streamDelegate: streamJoiner)
                streamJoiner.streamState = nsConfig.state
            }

            // wait for streams to open
            waitForAllStreamsOpen()
        }
        _ = try currentSync.proxy.dataSynchronizer.doSyncPass()
    }

    func watch(forEvents count: Int) throws {
        streamJoiner.wait(forEvents: count)
    }

    func powerCycleDevice() throws {
        try remoteCollAndSync.1.proxy.dataSynchronizer.reloadConfig()
        if streamJoiner.streamState != nil {
            streamJoiner.wait(forState: .closed)
        }
    }

    func teardown() {
        currentSync.proxy
            .dataSynchronizer
            .instanceChangeStreamDelegate.stop()
    }
}
