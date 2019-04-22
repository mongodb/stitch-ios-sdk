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
final class NamespaceSynchronization: Sequence, Codable {
    static func filter(namespace: MongoNamespace) -> Document {
        guard let namespaceDoc = try? BSONEncoder().encode(namespace) else {
            return ["namespace": BSONNull()]
        }
        return ["namespace": namespaceDoc]
    }

    enum CodingKeys: String, CodingKey {
        case namespace = "namespace", schemaVersion = "schema_version", docsColl = "docs_coll"
    }

    typealias Element = CoreDocumentSynchronization

    /// Standard read-write lock.
    lazy var nsLock: ReadWriteLock = ReadWriteLock(label: "namespace_lock_\(namespace)")
    /// The collection we are storing document configs in.
    private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>
    /// The error listener to propagate errors to.
    private weak var errorListener: FatalErrorListener?
    /// The conflict handler configured to this namespace.
    private(set) var conflictHandler: AnyConflictHandler?

    // this is not a normal delegate pattern, so this is okay
    // swiftlint:disable weak_delegate
    /// The change event listener configured to this namespace.
    private(set) var changeEventDelegate: AnyChangeEventDelegate?
    // swiftlint:enable weak_delegate

    var docs = [AnyBSONValue: CoreDocumentSynchronization]()
    let namespace: MongoNamespace

    /// Whether or not this namespace has been configured.
    var isConfigured: Bool {
        return self.conflictHandler != nil
    }

    init(docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>,
         namespace: MongoNamespace,
         errorListener: FatalErrorListener?) {
        self.docsColl = docsColl
        self.namespace = namespace
        self.errorListener = errorListener
    }

    /// Make an iterator that will iterate over the associated documents.
    func makeIterator() -> Dictionary<AnyBSONValue, CoreDocumentSynchronization>.Values.Iterator {
        return docs.values.makeIterator()
    }

    /// The number of documents synced on this namespace
    var count: Int {
        do {
            return try docsColl.count(CoreDocumentSynchronization.filter(forNamespace: namespace))
        } catch {
            return 0
        }
    }

    func sync(id: BSONValue) throws -> CoreDocumentSynchronization {
        nsLock.assertWriteLocked()
        if let existingConfig = self[id] {
            return existingConfig
        }
        let docConfig = CoreDocumentSynchronization.init(docsColl: docsColl,
                                                         namespace: self.namespace,
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
                if let config = docs[AnyBSONValue(documentId)] {
                    return config
                } else if let config = try docsColl.find(
                    docConfigFilter(forNamespace: namespace,
                                    withDocumentId: AnyBSONValue(documentId))).next() {
                    docs[AnyBSONValue(documentId)] = config
                    return config
                }

                return nil
            } catch {
                return nil
            }
        }
        set(value) {
            nsLock.assertWriteLocked()
            let documentId = AnyBSONValue(documentId)
            guard let value = value else {
                do {
                    try docsColl.deleteOne(
                        docConfigFilter(forNamespace: namespace,
                                        withDocumentId: documentId))
                } catch {
                    errorListener?.on(
                        error: error,
                        forDocumentId: documentId.value,
                        in: self.namespace
                    )
                }
                docs[documentId] = nil
                return
            }

            do {
                _ = try value.docLock.read {
                    try docsColl.replaceOne(
                        filter: docConfigFilter(forNamespace: self.namespace,
                                                withDocumentId: documentId),
                        replacement: value,
                        options: ReplaceOptions.init(upsert: true))
                }
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.value, in: self.namespace)
            }

            docs[documentId] = value
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
    var staleDocumentIds: Set<AnyBSONValue> {
        nsLock.assertLocked()
        do {
            return Set(
                try self.docsColl.distinct(
                    fieldName: CoreDocumentSynchronization.CodingKeys.documentId.rawValue,
                    filter: [
                        CoreDocumentSynchronization.CodingKeys.isStale.rawValue: true,
                        CoreDocumentSynchronization.CodingKeys.namespace.rawValue:
                            try BSONEncoder().encode(namespace)
                    ]).compactMap({
                        $0 == nil ? nil : AnyBSONValue($0!)
                    })
            )
        } catch {
            errorListener?.on(error: error, forDocumentId: nil, in: self.namespace)
            return Set()
        }
    }

    func set(stale: Bool) throws {
        _ = try nsLock.write {
            try docsColl.updateMany(
                filter: ["namespace": try BSONEncoder().encode(namespace)],
                update: ["$set": [
                    CoreDocumentSynchronization.CodingKeys.isStale.rawValue: true
                ] as Document])
        }
    }

    func encode(to encoder: Encoder) throws {
        try nsLock.read {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(namespace, forKey: .namespace)
            try container.encode(1, forKey: .schemaVersion)
            try container.encode(docsColl, forKey: .docsColl)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.namespace = try container.decode(MongoNamespace.self,
                                              forKey: .namespace)
        self.docsColl = try container.decode(ThreadSafeMongoCollection<CoreDocumentSynchronization>.self,
                                             forKey: .docsColl)
        try docsColl.find(CoreDocumentSynchronization.filter(forNamespace: namespace)).forEach { config in
            docs[config.documentId] = config
        }
    }
}
