import Foundation
import MongoSwift

/**
 The synchronization class for this instance.

 Instances contain a set of namespace configurations, which contains
 sets of document configurations.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal struct InstanceSynchronization: Sequence {
    /// The actual configuration to be persisted for this instance.
    struct Config: Codable {
        fileprivate var namespaces: [MongoNamespace: NamespaceSynchronization.Config]
    }

    /// Allows for the iteration of the namespaces contained in this instance.
    struct InstanceSynchronizationIterator: IteratorProtocol {
        typealias Element = NamespaceSynchronization
        private typealias Values = Dictionary<MongoNamespace, NamespaceSynchronization.Config>.Values

        private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
        private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
        private var values: Values
        private var indices: DefaultIndices<Values>
        private weak var errorListener: FatalErrorListener?

        init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
             docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<MongoNamespace, NamespaceSynchronization.Config>.Values,
             errorListener: FatalErrorListener?) {
            self.namespacesColl = namespacesColl
            self.docsColl = docsColl
            self.values = values
            self.indices = self.values.indices
            self.errorListener = errorListener
        }

        mutating func next() -> NamespaceSynchronization? {
            guard let index = self.indices.popFirst() else {
                return nil
            }

            return NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                 docsColl: docsColl,
                                                 config: &values[index],
                                                 errorListener: errorListener)
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
    }

    /// Make an iterator that will iterate over the associated namespaces.
    func makeIterator() -> InstanceSynchronizationIterator {
        return InstanceSynchronizationIterator.init(namespacesColl: namespacesColl,
                                                    docsColl: docsColl,
                                                    values: self.config.namespaces.values,
                                                    errorListener: errorListener)
    }

    /**
     Read a namespace configuration from this instance.
     If the namespace does not exist, one will be created for you.
     - parameter namespace: the namespace to read
     - returns: a new or existing NamespaceConfiguration
     */
    subscript(namespace: MongoNamespace) -> NamespaceSynchronization? {
        mutating get {
            instanceLock.writeLock()
            defer {
                instanceLock.unlock()
            }

            if var config = config.namespaces[namespace] {
                return NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                     docsColl: docsColl,
                                                     config: &config,
                                                     errorListener: errorListener)
            }

            do {
                let newConfig = try NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                                  docsColl: docsColl,
                                                                  namespace: namespace,
                                                                  errorListener: errorListener)
                try namespacesColl.insertOne(newConfig.config)
                config.namespaces[namespace] = newConfig.config
                return newConfig
            } catch {
                errorListener?.on(error: error, for: nil, in: namespace)
            }

            return nil
        }
    }
}
