import Foundation
import MongoSwift

struct InstanceSynchronization {
    struct Config: Codable {
        fileprivate var namespaces: [MongoNamespace: NamespaceSynchronization.Config]
    }

    struct InstanceSynchronizationIterator: IteratorProtocol {
        typealias Element = NamespaceSynchronization
        private typealias Values = Dictionary<MongoNamespace, NamespaceSynchronization.Config>.Values

        private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
        private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
        private var values: Values
        private var currentIndex: Values.Index

        init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
             docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<MongoNamespace, NamespaceSynchronization.Config>.Values) {
            self.namespacesColl = namespacesColl
            self.docsColl = docsColl
            self.values = values
            self.currentIndex = values.startIndex
        }

        mutating func next() -> NamespaceSynchronization? {
            guard values.endIndex != currentIndex else {
                return nil
            }
            currentIndex = values.index(after: currentIndex)
            return NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                 docsColl: docsColl,
                                                 config: values[currentIndex])
        }
    }

    private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
    private let instanceLock = ReadWriteLock()

    private(set) var config: Config

    init(configDb: MongoDatabase) {
        self.namespacesColl = try! configDb
            .collection("namespaces", withType: NamespaceSynchronization.Config.self)
        self.docsColl = try! configDb
            .collection("documents", withType: CoreDocumentSynchronization.Config.self)

        self.config = Config.init(
            namespaces: try! self.namespacesColl.find()
                .reduce(into: [MongoNamespace: NamespaceSynchronization.Config](),
                        { (syncedNamespaces, config) in
            syncedNamespaces[config.namespace] = config
        }))
    }

    func makeIterator() -> InstanceSynchronizationIterator {
        return InstanceSynchronizationIterator.init(namespacesColl: namespacesColl,
                                                    docsColl: docsColl,
                                                    values: self.config.namespaces.values)
    }

    subscript(namespace: MongoNamespace) -> NamespaceSynchronization {
        mutating get {
            instanceLock.readLock()
            instanceLock.writeLock()
            defer {
                instanceLock.unlock()
                instanceLock.unlock()
            }

            if let config = config.namespaces[namespace] {
                return NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                     docsColl: docsColl,
                                                     config: config)
            }

            instanceLock.writeLock()
            defer { instanceLock.unlock() }

            let newConfig = NamespaceSynchronization.init(namespacesColl: namespacesColl,
                                                          docsColl: docsColl,
                                                          namespace: namespace)
            try! namespacesColl.insertOne(newConfig.config)
            config.namespaces[namespace] = newConfig.config
            return newConfig
        }
    }
}
