import Foundation
import MongoMobile
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService

class InstanceSynchronizationConfigTests: XCMongoMobileTestCase, FatalErrorListener {
    private var namespaceColl: ThreadSafeMongoCollection<NamespaceSynchronization.Config>!
    private var docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization.Config>!

    private let namespace2 = MongoNamespace.init(databaseName: ObjectId().description,
                                                 collectionName: ObjectId().description)

    override func setUp() {
        namespaceColl = try! localClient.db(namespace.databaseName)
            .collection("namespaces", withType: NamespaceSynchronization.Config.self)
        docsColl = try! localClient.db(namespace.databaseName)
            .collection("documents", withType: CoreDocumentSynchronization.Config.self)
    }

    override func tearDown() {
        try? localClient.db(namespace2.databaseName).drop()
    }

    func on(error: Error, forDocumentId documentId: BSONValue?, in namespace: MongoNamespace?) {
        XCTFail(error.localizedDescription)
    }

    func testGet_Set_ModifyInPlace() throws {
        var instanceSync = try InstanceSynchronization.init(
            configDb: localClient.db(namespace.databaseName),
            errorListener: self)

        let nsConfig = try NamespaceSynchronization.init(namespacesColl: namespaceColl,
                                                         docsColl: docsColl,
                                                         namespace: namespace,
                                                         errorListener: nil)
        XCTAssertNotNil(instanceSync[namespace])

        XCTAssertEqual(instanceSync[namespace]?.config.namespace, nsConfig.config.namespace)

        let documentId = ObjectId()
        var nsConfig2 = instanceSync[namespace2]
        nsConfig2?[documentId] = try CoreDocumentSynchronization.init(docsColl: docsColl,
                                                                      namespace: namespace2,
                                                                      documentId: AnyBSONValue(documentId),
                                                                      errorListener: nil)

        XCTAssertEqual(2, instanceSync.map { $0 }.count)
        XCTAssertEqual(documentId, instanceSync[namespace2]?[documentId]?.documentId.value as? ObjectId)
    }
}
