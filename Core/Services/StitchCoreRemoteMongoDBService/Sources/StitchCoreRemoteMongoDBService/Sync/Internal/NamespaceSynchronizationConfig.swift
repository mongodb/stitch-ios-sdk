import Foundation
import MongoSwift
import MongoMobile
import StitchCoreSDK

/**
 The synchronization class for this namespace.

 Namespace configurations contain a set of document configurations.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal class NamespaceSynchronization: Sequence {
    /// The actual configuration to be persisted for this namespace.
    class Config: Codable {
        fileprivate enum CodingKeys: CodingKey {
            case syncedDocuments, namespace
        }
        /// the namespace for this config
        let namespace: MongoNamespace
        /// a map of documents synchronized on this namespace, keyed on their documentIds
        fileprivate(set) internal var syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization]
        /// The conflict handler configured to this namespace.
        fileprivate var conflictHandler: AnyConflictHandler?
        /// The change event listener configured to this namespace.
        fileprivate var changeEventDelegate: AnyChangeEventDelegate?

        init(namespace: MongoNamespace,
             syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization]) {
            self.namespace = namespace
            self.syncedDocuments = syncedDocuments
        }
    }

    typealias Element = CoreDocumentSynchronization
    typealias Iterator = NamespaceSynchronizationIterator

    /// Allows for the iteration of the document configs contained in this instance.
    struct NamespaceSynchronizationIterator: IteratorProtocol {
        typealias Element = CoreDocumentSynchronization
        private typealias Values = Dictionary<HashableBSONValue, CoreDocumentSynchronization>.Values

        private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>
        private var values: Values
        private var indices: DefaultIndices<Values>
        private weak var errorListener: FatalErrorListener?

        init(docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>,
             values: Dictionary<HashableBSONValue, CoreDocumentSynchronization>.Values,
             errorListener: FatalErrorListener?) {
            self.docsColl = docsColl
            self.values = values
            self.indices = self.values.indices
            self.errorListener = errorListener
        }

        mutating func next() -> CoreDocumentSynchronization? {
            guard let index = self.indices.popFirst() else {
                return nil
            }

            return values[index]
        }
    }

    /// Standard read-write lock.
    lazy var nsLock: ReadWriteLock = ReadWriteLock(label: "namespace_lock_\(config.namespace)")
    /// The collection we are storing namespace configs in.
    private let namespacesColl: ThreadSafeMongoCollection<NamespaceSynchronization.Config>
    /// The collection we are storing document configs in.
    private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>
    /// The error listener to propagate errors to.
    private weak var errorListener: FatalErrorListener?
    /// The configuration for this namespace.
    private(set) var config: Config
    /// The conflict handler configured to this namespace.
    private(set) var conflictHandler: AnyConflictHandler? {
        get {
            return self.config.conflictHandler
        }
        set {
            self.config.conflictHandler = newValue
        }
    }
    /// The change event listener configured to this namespace.
    private(set) var changeEventDelegate: AnyChangeEventDelegate? {
        get {
            return self.config.changeEventDelegate
        }
        set {
            self.config.changeEventDelegate = newValue
        }
    }

    /// Whether or not this namespace has been configured.
    var isConfigured: Bool {
        return self.conflictHandler != nil
    }

    init(namespacesColl: ThreadSafeMongoCollection<NamespaceSynchronization.Config>,
         docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>,
         namespace: MongoNamespace,
         errorListener: FatalErrorListener?) throws {
        self.namespacesColl = namespacesColl
        self.docsColl = docsColl
        // read the sync'd document configs from the local collection,
        // and map them into this nsConfig, keyed on their id
        self.config = Config.init(
            namespace: namespace,
            syncedDocuments: try docsColl
                .find(CoreDocumentSynchronization.filter(forNamespace: namespace))
                .reduce(into: [HashableBSONValue: CoreDocumentSynchronization](), { (syncedDocuments, config) in
                    syncedDocuments[config.documentId] = config
                }))
        self.errorListener = errorListener
    }

    /// Make an iterator that will iterate over the associated documents.
    func makeIterator() -> NamespaceSynchronization.Iterator {
        return NamespaceSynchronizationIterator.init(docsColl: docsColl,
                                                     values: config.syncedDocuments.values,
                                                     errorListener: errorListener)
    }

    /// The number of documents synced on this namespace
    var count: Int {
        return self.config.syncedDocuments.count
    }

    func sync(id: BSONValue) throws -> CoreDocumentSynchronization {
        nsLock.assertWriteLocked()
        if let existingConfig = self[id] {
            return existingConfig
        }
        let docConfig = try CoreDocumentSynchronization.init(docsColl: docsColl,
                                                             namespace: self.config.namespace,
                                                             documentId: AnyBSONValue(id),
                                                             errorListener: errorListener)
        self[id] = docConfig
        return docConfig
    }

    /**
     Read or set a document configuration from this namespace.
     If the document does not exist, one will not be returned.
     If the document does exist and nil is supplied, the document
     will be removed.
     - parameter documentId: the id of the document to read
     - returns: a new or existing NamespaceConfiguration
     */
    subscript(documentId: BSONValue) -> CoreDocumentSynchronization? {
        get {
            nsLock.assertLocked()
            do {
                return try docsColl.find(docConfigFilter(forNamespace: config.namespace,
                                                         withDocumentId: AnyBSONValue(documentId))).next()
            } catch {
                return config.syncedDocuments[HashableBSONValue(documentId)]
            }
        }
        set(value) {
            nsLock.assertWriteLocked()
            let documentId = HashableBSONValue(documentId)
            guard let value = value else {
                do {
                    try docsColl.deleteOne(
                        docConfigFilter(forNamespace: config.namespace,
                                        withDocumentId: documentId.bsonValue))
                    config.syncedDocuments.removeValue(forKey: documentId)
                } catch {
                    errorListener?.on(
                        error: error,
                        forDocumentId: documentId.bsonValue.value,
                        in: self.config.namespace
                    )
                }
                return
            }

            do {
                try docsColl.replaceOne(
                    filter: docConfigFilter(forNamespace: self.config.namespace,
                                            withDocumentId: documentId.bsonValue),
                    replacement: value,
                    options: ReplaceOptions.init(upsert: true))

                self.config.syncedDocuments[documentId] = value
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.bsonValue.value, in: self.config.namespace)
            }
        }
    }

    /**
     Configure a ConflictHandler and ChangeEventDelegate to this namespace.
     These will be used to handle conflicts or listen to events, for this namespace,
     respectively.
     
     - parameter conflictHandler: a ConflictHandler to handle conflicts on this namespace
     - parameter changeEventDelegate: a ChangeEventDelegate to listen to events on this namespace
     */
    func configure<T: ConflictHandler, V: ChangeEventDelegate>(conflictHandler: T,
                                                               changeEventDelegate: V?) {
        nsLock.write {
            self.conflictHandler = AnyConflictHandler(conflictHandler)
            if let changeEventDelegate = changeEventDelegate {
                self.changeEventDelegate = AnyChangeEventDelegate(changeEventDelegate,
                                                                  errorListener: errorListener)
            }
        }
    }

    /// A set of stale ids for the sync'd documents in this namespace.
    var staleDocumentIds: Set<HashableBSONValue> {
        nsLock.assertLocked()
        do {
            return Set(
                try self.docsColl.distinct(
                    fieldName: CoreDocumentSynchronization.CodingKeys.documentId.rawValue,
                    filter: [
                        CoreDocumentSynchronization.CodingKeys.isStale.rawValue: true,
                        CoreDocumentSynchronization.CodingKeys.namespace.rawValue:
                            try BSONEncoder().encode(config.namespace)
                    ]).compactMap({
                        $0 == nil ? nil : HashableBSONValue($0!)
                    })
            )
        } catch {
            errorListener?.on(error: error, forDocumentId: nil, in: self.config.namespace)
            return Set()
        }
    }

    func set(stale: Bool) throws {
        _ = try nsLock.write {
            try docsColl.updateMany(
                filter: ["namespace": try BSONEncoder().encode(config.namespace)],
                update: ["$set": [
                    CoreDocumentSynchronization.CodingKeys.isStale.rawValue: true
                ] as Document])
        }
    }
}
