import Foundation
import MongoSwift
import MongoMobile

struct NamespaceSynchronization: Sequence {
    struct Config: Codable {
        fileprivate enum CodingKeys: CodingKey {
            case syncedDocuments, namespace
        }

        /// the namespace for this config
        let namespace: MongoNamespace
        /// a map of documents synchronized on this namespace, keyed on their documentIds
        fileprivate var syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization.Config]
    }

    struct NamespaceSynchronizationIterator: IteratorProtocol {
        typealias Element = CoreDocumentSynchronization
        private typealias Values = Dictionary<HashableBSONValue, CoreDocumentSynchronization.Config>.Values

        private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
        private var values: Values
        private var currentIndex: Values.Index

        init(docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<HashableBSONValue, CoreDocumentSynchronization.Config>.Values) {
            self.docsColl = docsColl
            self.values = values
            self.currentIndex = values.startIndex
        }

        mutating func next() -> CoreDocumentSynchronization? {
            guard values.endIndex != currentIndex else {
                return nil
            }
            currentIndex = values.index(after: currentIndex)
            return CoreDocumentSynchronization.init(docsColl: docsColl,
                                                    config: values[currentIndex])
        }
    }

    /// the collection we are storing namespace configs in
    private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
    /// the collection we are storing document configs in
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>

    private let nsLock: ReadWriteLock = ReadWriteLock()
    private(set) var config: Config
    private(set) var conflictHandler: AnyConflictHandler?
    private(set) var changeEventListener: AnyChangeEventListener?

    var isConfigured: Bool {
        get {
            return self.conflictHandler != nil
        }
    }

    typealias Element = CoreDocumentSynchronization
    typealias Iterator = NamespaceSynchronizationIterator

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         namespace: MongoNamespace) {
        self.namespacesColl = namespacesColl
        self.docsColl = docsColl
        self.config = Config.init(
            namespace: namespace,
            syncedDocuments: try! docsColl
                .find(CoreDocumentSynchronization.filter(forNamespace: namespace))
                .reduce(into: [HashableBSONValue: CoreDocumentSynchronization.Config](), { (syncedDocuments, config) in
                    syncedDocuments[config.documentId] = config
                }))

    }

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         config: Config) {
        self.namespacesColl = namespacesColl
        self.docsColl = docsColl
        self.config = config
    }

    func makeIterator() -> NamespaceSynchronization.Iterator {
        return NamespaceSynchronizationIterator.init(docsColl: docsColl,
                                                     values: config.syncedDocuments.values)
    }

    subscript(documentId: HashableBSONValue) -> CoreDocumentSynchronization? {
        get {
            nsLock.readLock()
            defer { nsLock.unlock() }
            guard let config = config.syncedDocuments[documentId] else {
                return nil
            }
            return CoreDocumentSynchronization.init(docsColl: docsColl, config: config)
        }
        set(value) {
            nsLock.writeLock()
            defer { nsLock.unlock() }
            
            guard let value = value else {
                try! docsColl.deleteOne(NamespaceSynchronization.docFilter(forNamespace: config.namespace,
                                                                           withDocumentId: documentId))
                config.syncedDocuments[documentId] = nil
                return
            }

            let newConfig: CoreDocumentSynchronization =
                CoreDocumentSynchronization.init(docsColl: docsColl,
                                                 config: value.config)

            try! docsColl.replaceOne(
                filter: NamespaceSynchronization.docFilter(forNamespace: self.config.namespace,
                                                           withDocumentId: documentId),
                replacement: newConfig.config,
                options: ReplaceOptions.init(upsert: true))
            self.config.syncedDocuments[documentId] = newConfig.config
        }
    }

    mutating func configure<T: ConflictHandler, V: ChangeEventListener>(conflictHandler: T,
                                                                        changeEventListener: V) {
        nsLock.writeLock()
        defer { nsLock.unlock() }
        self.conflictHandler = AnyConflictHandler(conflictHandler)
        self.changeEventListener = AnyChangeEventListener(changeEventListener)
    }

    var staleDocumentIds: Set<HashableBSONValue> {
        get {
            nsLock.readLock()
            defer { nsLock.unlock() }
            return Set(try! self.docsColl.distinct(
                fieldName: CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue,
                filter: [CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue:
                    [CoreDocumentSynchronization.Config.CodingKeys.isStale.rawValue: true] as Document
                ]).compactMap({$0 == nil ? nil : HashableBSONValue($0!)}))
        }
    }

    static func docFilter(forNamespace namespace: MongoNamespace,
                                withDocumentId documentId: HashableBSONValue) -> Document {
        return [
            Config.CodingKeys.namespace.stringValue: namespace.description,
            CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue: documentId.bsonValue.value
        ]
    }
}
