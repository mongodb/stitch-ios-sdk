import Foundation
import MongoMobile
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService

class InstanceSynchronizationConfigTests: XCMongoMobileTestCase {
    private var namespaceColl: MongoCollection<NamespaceSynchronization.Config>!
    private var docsColl: MongoCollection<CoreDocumentSynchronization.Config>!

    private let namespace = MongoNamespace.init(databaseName: ObjectId().description,
                                                collectionName: ObjectId().description)
    private let namespace2 = MongoNamespace.init(databaseName: ObjectId().description,
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

    func testGet_Set_ModifyInPlace() throws {
        var instanceSync = InstanceSynchronization.init(
            configDb: try XCMongoMobileTestCase.client.db(namespace.databaseName))

        let nsConfig = NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                     docsColl: docsColl,
                                                     namespace: namespace)
        XCTAssertNotNil(instanceSync[namespace])

        XCTAssertEqual(instanceSync[namespace].config, nsConfig.config)

        let documentId = HashableBSONValue(ObjectId())
        var nsConfig2 = instanceSync[namespace2]
        nsConfig2[documentId] = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                                 namespace: namespace2,
                                                                 documentId: documentId.bsonValue)

        XCTAssertEqual(2, instanceSync.map { $0 }.count)
        print(nsConfig2.map { $0 }.count)
        print(instanceSync[namespace2].map { $0 }.count)

        XCTAssertEqual(documentId, HashableBSONValue((instanceSync[namespace2][documentId]?.documentId)!))
    }
}
