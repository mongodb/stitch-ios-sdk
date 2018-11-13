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

    func testSet() {
        let documentId = HashableBSONValue(ObjectId())
        var nsConfig = NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                     docsColl: docsColl,
                                                     namespace: namespace)

        var docConfig = nsConfig[documentId]

        XCTAssertNil(docConfig)

        docConfig = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                     namespace: namespace,
                                                     documentId: documentId.bsonValue)

        nsConfig[documentId] = docConfig

        XCTAssertEqual(docConfig, nsConfig[documentId])

        nsConfig[documentId] = nil

        XCTAssertEqual(nil, nsConfig[documentId])
    }

    func testStaleDocumentIds() {
        let documentIds = [
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId()),
            HashableBSONValue(ObjectId())
        ]

        var nsConfig = NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                     docsColl: docsColl,
                                                     namespace: namespace)

        var docConfigs = [
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[0].bsonValue),
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[1].bsonValue),
            CoreDocumentSynchronization.init(docsColl: docsColl,
                                             namespace: namespace,
                                             documentId: documentIds[2].bsonValue)
        ]

        docConfigs.forEach { nsConfig[HashableBSONValue($0.documentId)] = $0 }

        docConfigs[1].isStale = true

        try! docsColl.find().forEach { print($0) }
        XCTAssertEqual(1, nsConfig.staleDocumentIds.count)
        XCTAssertEqual(documentIds[1], nsConfig.staleDocumentIds.first)
        XCTAssertEqual(3, nsConfig.map { $0 }.count)
    }
}
