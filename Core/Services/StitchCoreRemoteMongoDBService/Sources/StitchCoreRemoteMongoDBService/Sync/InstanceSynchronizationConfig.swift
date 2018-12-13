import Foundation
import MongoSwift

/**
 The synchronization class for this instance.

 Instances contain a set of namespace configurations, which contains
 sets of document configurations.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal class InstanceSynchronization: Sequence {
    /// The actual configuration to be persisted for this instance.
    class Config: Codable {
        fileprivate(set) internal var namespaces: [MongoNamespace: NamespaceSynchronization.Config]

        init(namespaces: [MongoNamespace: NamespaceSynchronization.Config]) {
            self.namespaces = namespaces
        }
    }

    fileprivate var namespaceConfigWrappers: [MongoNamespace: NamespaceSynchronization]

    /// Allows for the iteration of the namespaces contained in this instance.
    struct InstanceSynchronizationIterator: IteratorProtocol {
        typealias Element = NamespaceSynchronization
        private typealias Values = Dictionary<MongoNamespace, NamespaceSynchronization>.Values

        private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
        private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
        private var values: Values
        private var indices: DefaultIndices<Values>
        private weak var errorListener: FatalErrorListener?
        private weak var parentInstanceLock: ReadWriteLock?

        init(instanceLock: ReadWriteLock,
             namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
             docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<MongoNamespace, NamespaceSynchronization>.Values,
             errorListener: FatalErrorListener?) {
            self.namespacesColl = namespacesColl
            self.docsColl = docsColl
            self.values = values
            self.indices = self.values.indices
            self.errorListener = errorListener
            self.parentInstanceLock = instanceLock

            self.parentInstanceLock?.writeLock()
        }

        mutating func next() -> NamespaceSynchronization? {
            guard let index = self.indices.popFirst() else {
                self.parentInstanceLock?.unlock()
                return nil
            }

            return values[index]
        }
    }

    private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
    private let instanceLock = ReadWriteLock()
    weak var errorListener: FatalErrorListener?

    /// The configuration for this instance.
    private(set) var config: Config

    init(configDb: MongoDatabase,
         errorListener: FatalErrorListener?) throws {
        self.namespacesColl = try configDb
            .collection("namespaces", withType: NamespaceSynchronization.Config.self)
        self.docsColl = try configDb
            .collection("documents", withType: CoreDocumentSynchronization.Config.self)

        self.config = Config.init(
            namespaces: try self.namespacesColl.find()
                .reduce(into: [MongoNamespace: NamespaceSynchronization.Config](),
                        { (syncedNamespaces, config) in
                            syncedNamespaces[config.namespace] = config
                }))
        self.errorListener = errorListener

        let nsColl = namespacesColl
        let dColl = docsColl
        self.namespaceConfigWrappers = try self.config.namespaces.mapValues { nsConfig in
            return try NamespaceSynchronization.init(
                namespacesColl: nsColl,
                docsColl: dColl,
                namespace: nsConfig.namespace,
                errorListener: errorListener
            )
        }
    }

    /// Make an iterator that will iterate over the associated namespaces.
    func makeIterator() -> InstanceSynchronizationIterator {
        return InstanceSynchronizationIterator.init(instanceLock: instanceLock,
                                                    namespacesColl: namespacesColl,
                                                    docsColl: docsColl,
                                                    values: namespaceConfigWrappers.values,
                                                    errorListener: errorListener)
    }

    /**
     Read a namespace configuration from this instance.
     If the namespace does not exist, one will be created for you.
     - parameter namespace: the namespace to read
     - returns: a new or existing NamespaceConfiguration
     */
    subscript(namespace: MongoNamespace) -> NamespaceSynchronization? {
        get {
            instanceLock.writeLock()
            defer {
                instanceLock.unlock()
            }

            if let config = namespaceConfigWrappers[namespace] {
                return config
            }

            do {
                let newConfig = try NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                                  docsColl: docsColl,
                                                                  namespace: namespace,
                                                                  errorListener: errorListener)
                try namespacesColl.insertOne(newConfig.config)
                namespaceConfigWrappers[namespace] = newConfig
                return newConfig
            } catch {
                errorListener?.on(error: error, forDocumentId: nil, in: namespace)
            }

            return nil
        }
    }
}
