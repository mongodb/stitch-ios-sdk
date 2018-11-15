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
    class Config: Codable, Hashable {
        fileprivate enum CodingKeys: CodingKey {
            case syncedDocuments, namespace
        }
        /// the namespace for this config
        let namespace: MongoNamespace
        /// a map of documents synchronized on this namespace, keyed on their documentIds
        fileprivate var syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization.Config]

        init(namespace: MongoNamespace,
             syncedDocuments: [HashableBSONValue: CoreDocumentSynchronization.Config]) {
            self.namespace = namespace
            self.syncedDocuments = syncedDocuments
        }

        static func == (lhs: NamespaceSynchronization.Config, rhs: NamespaceSynchronization.Config) -> Bool {
            return lhs.namespace == rhs.namespace
        }

        func hash(into hasher: inout Hasher) {
            namespace.hash(into: &hasher)
            syncedDocuments.hash(into: &hasher)
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
        private weak var errorListener: ErrorListener?

        init(docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
             values: Dictionary<HashableBSONValue, CoreDocumentSynchronization.Config>.Values,
             errorListener: ErrorListener?) {
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

    /// The collection we are storing namespace configs in.
    private let namespacesColl: MongoCollection<NamespaceSynchronization.Config>
    /// The collection we are storing document configs in.
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
    /// Standard read-write lock.
    private let nsLock: ReadWriteLock = ReadWriteLock()
    /// The error listener to propagate errors to.
    private weak var errorListener: ErrorListener?
    /// The configuration for this namespace.
    private(set) var config: Config
    /// The conflict handler configured to this namespace.
    private(set) var conflictHandler: AnyConflictHandler?
    /// The change event listener configured to this namespace.
    private(set) var changeEventListener: AnyChangeEventListener?

    /// Whether or not this namespace has been configured.
    var isConfigured: Bool {
        get {
            return self.conflictHandler != nil
        }
    }

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         namespace: MongoNamespace,
         errorListener: ErrorListener?) throws {
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

    }

    init(namespacesColl: MongoCollection<NamespaceSynchronization.Config>,
         docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         config: inout Config,
         errorListener: ErrorListener?) {
        self.namespacesColl = namespacesColl
        self.docsColl = docsColl
        self.config = config
    }

    /// Make an iterator that will iterate over the associated documents.
    func makeIterator() -> NamespaceSynchronization.Iterator {
        return NamespaceSynchronizationIterator.init(docsColl: docsColl,
                                                     values: config.syncedDocuments.values,
                                                     errorListener: errorListener)
    }

    /**
     Read or set a document configuration from this namespace.
     If the document does not exist, one will not be returned.
     If the document does exist and nil is supplied, the document
     will be removed.
     - parameter documentId: the id of the document to read
     - returns: a new or existing NamespaceConfiguration
     */
    subscript(documentId: HashableBSONValue) -> CoreDocumentSynchronization? {
        get {
            nsLock.readLock()
            defer { nsLock.unlock() }
            guard var config = config.syncedDocuments[documentId] else {
                return nil
            }
            return CoreDocumentSynchronization.init(docsColl: docsColl,
                                                    config: &config,
                                                    errorListener: errorListener)
        }
        set(value) {
            nsLock.writeLock()
            defer { nsLock.unlock() }
            
            guard let value = value else {
                do {
                    try docsColl.deleteOne(docConfigFilter(forNamespace: config.namespace,
                                                           withDocumentId: documentId.bsonValue))
                } catch {
                    errorListener?.on(error: error, forDocumentId: documentId.bsonValue.value)
                }
                config.syncedDocuments[documentId] = nil
                return
            }

            do {
                try docsColl.replaceOne(
                    filter: docConfigFilter(forNamespace: self.config.namespace,
                                            withDocumentId: documentId.bsonValue),
                    replacement: value.config,
                    options: ReplaceOptions.init(upsert: true))
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.bsonValue.value)
            }
            self.config.syncedDocuments[documentId] = value.config
        }
    }

    /**
     Configure a ConflictHandler and ChangeEventListener to this namespace.
     These will be used to handle conflicts or listen to events, for this namespace,
     respectively.

     TODO STITCH-2212: Add typealias lambdas to the higher level call for this function.
     
     - parameter conflictHandler: a ConflictHandler to handle conflicts on this namespace
     - parameter changeEventListener: a ChangeEventListener to listen to events on this namespace
     */
    mutating func configure<T: ConflictHandler, V: ChangeEventListener>(conflictHandler: T,
                                                                        changeEventListener: V) {
        nsLock.writeLock()
        defer { nsLock.unlock() }
        self.conflictHandler = AnyConflictHandler(conflictHandler)
        self.changeEventListener = AnyChangeEventListener(changeEventListener,
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
                errorListener?.on(error: error, forDocumentId: nil)
                return Set()
            }
        }
    }
}
