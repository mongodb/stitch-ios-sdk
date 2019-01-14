// swiftlint:disable nesting
import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class NamespaceSynchronizationConfigTests: XCMongoMobileTestCase {
    private var namespaceColl: ThreadSafeMongoCollection<NamespaceSynchronization>!
    private var docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>!

    override func setUp() {
        namespaceColl = localClient.db(namespace.databaseName)
            .collection("namespaces", withType: NamespaceSynchronization.self)
        docsColl = localClient.db(namespace.databaseName)
            .collection("documents", withType: CoreDocumentSynchronization.self)
    }

    override func tearDown() {
        try? localClient.db(namespace.databaseName).drop()
    }

    func testSet() throws {
        let documentId = ObjectId()
        let nsConfig = NamespaceSynchronization.init(docsColl: docsColl,
                                                         namespace: namespace,
                                                         errorListener: nil)

        try nsConfig.nsLock.write {
            var docConfig = nsConfig[documentId]

            XCTAssertNil(docConfig)

            docConfig = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                             namespace: namespace,
                                                             documentId: AnyBSONValue(documentId),
                                                             errorListener: nil)

            nsConfig[documentId] = docConfig

            XCTAssertEqual(docConfig, nsConfig[documentId])

            nsConfig[documentId] = nil

            XCTAssertEqual(nil, nsConfig[documentId])
        }
    }

    func testStaleDocumentIds() throws {
        class TestErrorListener: FatalErrorListener {
            public init() {
            }

            func on(error: Error, forDocumentId documentId: BSONValue?, in namespace: MongoNamespace?) {
                XCTFail(error.localizedDescription)
            }
        }
        let errorListener = TestErrorListener()

        let documentIds = [
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId())
        ]

        let nsConfig = NamespaceSynchronization.init(docsColl: docsColl,
                                                         namespace: namespace,
                                                         errorListener: errorListener)

        var docConfigs = [
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[0].bsonValue,
                                             errorListener: errorListener),
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[1].bsonValue,
                                             errorListener: errorListener),
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[2].bsonValue,
                                             errorListener: errorListener)
        ]

        docConfigs.forEach { docConfig in
            nsConfig.nsLock.write {
                nsConfig[docConfig.documentId.value] = docConfig
            }
        }

        docConfigs[1].isStale = true

        nsConfig.nsLock.read {
            XCTAssertEqual(1, nsConfig.staleDocumentIds.count)
            XCTAssertEqual(documentIds[1], nsConfig.staleDocumentIds.first)
            XCTAssertEqual(3, nsConfig.map { $0 }.count)
        }
    }
}
