import Foundation
import MongoSwift
import StitchCoreSDK

/**
 The synchronization class for this instance.

 Instances contain a set of namespace configurations, which contains
 sets of document configurations.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
final class InstanceSynchronization: Sequence, Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version",
        namespacesColl = "namespaces_coll",
        docsColl = "docs_coll"
    }

    private let namespacesColl: ThreadSafeMongoCollection<NamespaceSynchronization>
    private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>
    private lazy var instanceLock: ReadWriteLock = ReadWriteLock(label: "sync_instance")
    weak var errorListener: FatalErrorListener?
    private var namespaceConfigs: [MongoNamespace: NamespaceSynchronization] = [:]

    init(configDb: ThreadSafeMongoDatabase,
         errorListener: FatalErrorListener?) throws {
        self.namespacesColl = configDb
            .collection("namespaces", withType: NamespaceSynchronization.self)
        self.docsColl = configDb
            .collection("documents", withType: CoreDocumentSynchronization.self)
        self.errorListener = errorListener
    }

    /// Make an iterator that will iterate over the associated namespaces.
    func makeIterator() -> Dictionary<MongoNamespace, NamespaceSynchronization>.Values.Iterator {
        return namespaceConfigs.values.makeIterator()
    }

    /**
     Read a namespace configuration from this instance.
     If the namespace does not exist, one will be created for you.
     - parameter namespace: the namespace to read
     - returns: a new or existing NamespaceConfiguration
     */
    subscript(namespace: MongoNamespace) -> NamespaceSynchronization? {
        if let config: NamespaceSynchronization = instanceLock.read({
            if let config = self.namespaceConfigs[namespace] {
                return config
            }

            if let cursor = try? namespacesColl.find(NamespaceSynchronization.filter(namespace: namespace)) {
                let config = cursor.next()
                namespaceConfigs[namespace] = config
                return config
            }

            return nil
        }) {
            return config
        }

        return instanceLock.write {
            do {
                let newConfig = NamespaceSynchronization.init(docsColl: docsColl,
                                                              namespace: namespace,
                                                              errorListener: errorListener)
                try namespacesColl.insertOne(newConfig)
                namespaceConfigs[namespace] = newConfig
                return newConfig
            } catch {
                errorListener?.on(error: error, forDocumentId: nil, in: namespace)
            }

            return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        try instanceLock.read {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(1, forKey: .schemaVersion)
            try container.encode(namespacesColl, forKey: .namespacesColl)
            try container.encode(docsColl, forKey: .docsColl)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        namespacesColl = try container.decode(ThreadSafeMongoCollection<NamespaceSynchronization>.self,
                                              forKey: .namespacesColl)
        docsColl = try container.decode(ThreadSafeMongoCollection<CoreDocumentSynchronization>.self,
                                        forKey: .docsColl)

        try namespacesColl.find().forEach { config in
            namespaceConfigs[config.namespace] = config
        }
    }
}
