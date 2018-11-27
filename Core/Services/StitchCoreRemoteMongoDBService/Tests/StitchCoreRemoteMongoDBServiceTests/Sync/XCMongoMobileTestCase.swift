import Foundation
import XCTest
import MongoMobile
import MongoSwift
import StitchCoreSDK
@testable import StitchCoreRemoteMongoDBService
import StitchCoreSDKMocks

class XCMongoMobileConfiguration: NSObject, XCTestObservation {
    // This init is called first thing as the test bundle starts up and before any test
    // initialization happens
    override init() {
        super.init()
        // We don't need to do any real work, other than register for callbacks
        // when the test suite progresses.
        // XCTestObservation keeps a strong reference to observers
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        try! MongoMobile.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        try? MongoMobile.close()
    }
}

class XCMongoMobileTestCase: XCTestCase {
    static var client: MongoClient!
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

    private class DeinitializingDataSynchronizer: DataSynchronizer {
        private let deinitializingInstanceKey: String
        init(instanceKey: String) throws {
            self.deinitializingInstanceKey = instanceKey
            let mockServiceClient = MockCoreStitchServiceClient.init()
            try super.init(
                instanceKey: instanceKey,
                service: mockServiceClient,
                localClient: XCMongoMobileTestCase.client,
                remoteClient: CoreRemoteMongoClient.init(withService: mockServiceClient),
                networkMonitor: TestNetworkMonitor(),
                authMonitor: TestAuthMonitor())
        }

        deinit {
            try? XCMongoMobileTestCase.client.db(
                DataSynchronizer
                    .localConfigDBName(withInstanceKey: deinitializingInstanceKey)
                ).drop()
        }
    }

    final lazy var dataSynchronizer: DataSynchronizer =
        try! DeinitializingDataSynchronizer.init(instanceKey: instanceKey.oid)

    private var _instanceKey = ObjectId()
    open var instanceKey: ObjectId {
        return _instanceKey
    }

    private var _namespace = MongoNamespace.init(databaseName: "db", collectionName: "coll")
    open var namespace: MongoNamespace {
        return _namespace
    }

    override class func setUp() {
        let path = "\(FileManager().currentDirectoryPath)/path/local_mongodb/0/"
        var isDir : ObjCBool = true
        if !FileManager().fileExists(atPath: path, isDirectory: &isDir) {
            try! FileManager().createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        let settings = MongoClientSettings(dbPath: path)
        client = try! MongoMobile.create(settings)
    }

    private var namespacesToBeTornDown = Set<MongoNamespace>()
    override func tearDown() {
        namespacesToBeTornDown.forEach {
            try? XCMongoMobileTestCase.client.db($0.databaseName).drop()
        }
    }

    func defaultCollection(for namespace: MongoNamespace = MongoNamespace(databaseName: "db",
                                                                          collectionName: "coll")) throws -> MongoCollection<Document> {
        self.namespacesToBeTornDown.insert(namespace)
        return try XCMongoMobileTestCase.client
            .db(namespace.databaseName)
            .collection(namespace.collectionName, withType: Document.self)
    }
}
