import Foundation
import MongoSwift
import MongoMobile

/**
 The synchronization class for this namespace.

 Namespace configurations contain a set of document configurations.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal struct NamespaceSynchronization: Sequence {
    /// The actual configuration to be persisted for this namespace.
    class Config: Codable {
        fileprivate enum CodingKeys: CodingKey {
            case syncedDocuments, namespace
        }
        /// the namespace for this config
        let namespace: MongoNamespace
        /// a map of documents synchronized on this namespace, keyed on their documentIds
        fileprivate var syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization.Config]
        /// The conflict handler configured to this namespace.
        fileprivate var conflictHandler: AnyConflictHandler?
        /// The change event listener configured to this namespace.
        fileprivate var changeEventDelegate: AnyChangeEventDelegate?

        init(namespace: MongoNamespace,
             syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization.Config]) {
            self.namespace = namespace
            self.syncedDocuments = syncedDocuments
        }
    }

    typealias Element = CoreDocumentSynchronization
    typealias Iterator = NamespaceSynchronizationIterator

    /// Allows for the iteration of the document configs contained in this instance.
    struct NamespaceSynchronizationIterator: IteratorProtocol {
        typealias Element = CoreDocumentSynchronization
        private typealias Values = Dictionary<HashableBSONValue, CoreDocumentSynchronization.Config>.Values

        private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
        private var values: Values
        private var indices: DefaultIndices<Values>
        private weak var errorListener: FatalErrorListener?

        init(docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<HashableBSONValue, CoreDocumentSynchronization.Config>.Values,
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

            return CoreDocumentSynchronization.init(docsColl: docsColl,
                                                    config: &values[index],
                                                    errorListener: errorListener)
        }
    }

    /// Standard read-write lock.
    let nsLock: ReadWriteLock = ReadWriteLock()
    /// The collection we are storing namespace configs in.
    private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
    /// The collection we are storing document configs in.
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
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
        get {
            return self.conflictHandler != nil
        }
    }

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
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
                .reduce(into: [HashableBSONValue: CoreDocumentSynchronization.Config](), { (syncedDocuments, config) in
                    syncedDocuments[config.documentId] = config
                }))
        self.errorListener = errorListener
    }

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         config: inout Config,
         errorListener: FatalErrorListener?) {
        self.namespacesColl = namespacesColl
        self.docsColl = docsColl
        self.config = config
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

    mutating func sync(id: BSONValue) -> CoreDocumentSynchronization {
        let docConfig = CoreDocumentSynchronization.init(docsColl: docsColl,
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
            nsLock.readLock()
            defer { nsLock.unlock() }
            guard var config = config.syncedDocuments[HashableBSONValue(documentId)] else {
                return nil
            }
            return CoreDocumentSynchronization.init(docsColl: docsColl,
                                                    config: &config,
                                                    errorListener: errorListener)
        }
        set(value) {
            nsLock.writeLock()
            defer { nsLock.unlock() }
            let documentId = HashableBSONValue(documentId)
            guard let value = value else {
                do {
                    try docsColl.deleteOne(docConfigFilter(forNamespace: config.namespace,
                                                           withDocumentId: documentId.bsonValue))
                    config.syncedDocuments[documentId] = nil
                } catch {
                    errorListener?.on(error: error, forDocumentId: documentId.bsonValue.value, in: self.config.namespace)
                }
                return
            }

            do {
                try docsColl.replaceOne(
                    filter: docConfigFilter(forNamespace: self.config.namespace,
                                            withDocumentId: documentId.bsonValue),
                    replacement: value.config,
                    options: ReplaceOptions.init(upsert: true))
                self.config.syncedDocuments[documentId] = value.config
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
    mutating func configure<T: ConflictHandler, V: ChangeEventDelegate>(conflictHandler: T,
                                                                        changeEventDelegate: V) {
        nsLock.writeLock()
        defer { nsLock.unlock() }
        self.conflictHandler = AnyConflictHandler(conflictHandler)
        self.changeEventDelegate = AnyChangeEventDelegate(changeEventDelegate,
                                                          errorListener: errorListener)
    }

    /// A set of stale ids for the sync'd documents in this namespace.
    var staleDocumentIds: Set<HashableBSONValue> {
        get {
            nsLock.readLock()
            defer { nsLock.unlock() }
            do {
                return Set(
                    try self.docsColl.distinct(
                        fieldName: CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue,
                        filter: [CoreDocumentSynchronization.Config.CodingKeys.isStale.rawValue: true] as Document
                    ).compactMap({$0 == nil ? nil : HashableBSONValue($0!)})
                )
            } catch {
                errorListener?.on(error: error, forDocumentId: nil, in: self.config.namespace)
                return Set()
            }
        }
    }
}
