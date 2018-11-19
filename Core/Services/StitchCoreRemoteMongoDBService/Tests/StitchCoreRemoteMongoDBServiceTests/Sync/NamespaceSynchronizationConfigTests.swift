import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class NamespaceSynchronizationConfigTests: XCMongoMobileTestCase {
    private var namespaceColl: MongoCollection<NamespaceSynchronization.Config>!
    private var docsColl: MongoCollection<CoreDocumentSynchronization.Config>!

    private var namespace = MongoNamespace.init(databaseName: ObjectId().description,
                                                collectionName: ObjectId().description)

    override func setUp() {
        namespaceColl = try! XCMongoMobileTestCase.client.db(namespace.databaseName)
            .collection("namespaces", withType: NamespaceSynchronization.Config.self)
        docsColl = try! XCMongoMobileTestCase.client.db(namespace.databaseName)
            .collection("documents", withType: CoreDocumentSynchronization.Config.self)
    }

    override func tearDown() {
        try? XCMongoMobileTestCase.client.db(namespace.databaseName).drop()
    }

    func testSet() throws {
        let documentId = ObjectId()
        var nsConfig = try NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                         docsColl: docsColl,
                                                         namespace: namespace,
                                                         errorListener: nil)

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

    func testStaleDocumentIds() throws {
        class TestErrorListener: FatalErrorListener {
            public init() {
            }

            func on(error: Error, for documentId: BSONValue?, in namespace: MongoNamespace?) {
                XCTFail(error.localizedDescription)
            }
        }
        let errorListener = TestErrorListener()

        let documentIds = [
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId())
        ]

        var nsConfig = try NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                         docsColl: docsColl,
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

        docConfigs.forEach { nsConfig[$0.documentId.value] = $0 }

        docConfigs[1].isStale = true

        XCTAssertEqual(1, nsConfig.staleDocumentIds.count)
        XCTAssertEqual(documentIds[1], nsConfig.staleDocumentIds.first)
        XCTAssertEqual(3, nsConfig.map { $0 }.count)
    }
}
