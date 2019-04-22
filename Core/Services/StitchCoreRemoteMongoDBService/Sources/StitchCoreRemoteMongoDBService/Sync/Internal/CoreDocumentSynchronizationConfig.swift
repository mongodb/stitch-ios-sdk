import Foundation
import MongoMobile
import MongoSwift
import StitchCoreSDK

/**
 Returns a query filter for a document with a given
 namespace and documentId.
 - parameter namespace: the namespace the document is in
 - parameter documentId: the id of the document
 - returns: a query filter to find a document
 */
internal func docConfigFilter(forNamespace namespace: MongoNamespace,
                              withDocumentId documentId: AnyBSONValue) -> Document {
    guard let namespaceDoc = try? BSONEncoder().encode(namespace) else {
        return [CoreDocumentSynchronization.CodingKeys.namespace.rawValue: BSONNull(),
         CoreDocumentSynchronization.CodingKeys.documentId.rawValue: documentId.value]
    }
    return [CoreDocumentSynchronization.CodingKeys.namespace.rawValue: namespaceDoc,
            CoreDocumentSynchronization.CodingKeys.documentId.rawValue: documentId.value]
}

/**
 The synchronization class for this document.

 Document configurations contain information about a synchronized document.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
final class CoreDocumentSynchronization: Codable, Hashable {
    enum CodingKeys: String, CodingKey {
        // These are snake_case because we are trying to keep the internal
        // representation consistent across platforms
        case namespace = "namespace", documentId = "document_id",
        uncommittedChangeEvent = "last_uncommitted_change_event",
        lastResolution = "last_resolution", lastKnownRemoteVersion = "last_known_remote_version",
        isStale = "is_stale", isPaused = "is_paused", schemaVersion = "schema_version"
        case docsColl = "docs_coll"
    }

    /// The collection we are storing document configs in.
    private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>
    /// The error listener to propogate errors to.
    private weak var errorListener: FatalErrorListener?
    /// Standard read-write lock.
    lazy var docLock: ReadWriteLock = ReadWriteLock(label: "document_lock_\(namespace)_\(documentId.value)")
    /// The namespace this document is stored in.
    let namespace: MongoNamespace
    /// The id of this document.
    let documentId: AnyBSONValue

    private var _uncommittedChangeEvent: ChangeEvent<Document>?
    /// The most recent pending change event
    private(set) var uncommittedChangeEvent: ChangeEvent<Document>? {
        get {
            return docLock.read { _uncommittedChangeEvent }
        }
        set {
            docLock.assertWriteLocked()
            _uncommittedChangeEvent = newValue
        }
    }
    private var _lastResolution: Int64
    /// The last time a pending write has been triggered.
    private(set) var lastResolution: Int64 {
        get {
            return docLock.read { _lastResolution }
        }
        set {
            docLock.assertWriteLocked()
            _lastResolution = newValue
        }
    }
    private var _lastKnownRemoteVersion: Document?
    /// The last known remote version.
    private(set) var lastKnownRemoteVersion: Document? {
        get {
            return docLock.read { _lastKnownRemoteVersion }
        }
        set {
            docLock.assertWriteLocked()
            _lastKnownRemoteVersion = newValue
        }
    }

    private var _isStale: Bool
    /// Whether or not this document has gone stale.
    var isStale: Bool {
        get {
            return docLock.read {
                var filter = docConfigFilter(forNamespace: namespace, withDocumentId: documentId).map {
                    ($0.key, $0.value)
                }
                filter.append((CodingKeys.isStale.rawValue, true))
                let filterDoc = filter.reduce(into: Document(), { (doc, kvp) in
                    doc[kvp.0] = kvp.1
                })
                do {
                    let count = try docsColl.count(filterDoc)
                    return count == 1
                } catch {
                    errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
                    return self._isStale
                }
            }
        }
        set(value) {
            docLock.write {
                do {
                    try docsColl.updateOne(
                        filter: docConfigFilter(forNamespace: namespace, withDocumentId: documentId),
                        update: ["$set": [CodingKeys.isStale.rawValue: value] as Document])
                } catch {
                    errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
                }
                self._isStale = value
            }
        }
    }

    private var _isPaused: Bool
    /// Whether or not this document has been paused due to an error.
    var isPaused: Bool {
        get {
            return docLock.read { return self._isPaused }
        }
        set(value) {
            docLock.write {
                do {
                    try docsColl.updateOne(
                        filter: docConfigFilter(forNamespace: namespace,
                                                withDocumentId: documentId),
                        update: ["$set": [ CodingKeys.isPaused.rawValue: value ] as Document])
                } catch {
                    errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
                }
                self._isPaused = value
            }
        }
    }

    /// Whether or not there is a pending write for this document.
    var hasUncommittedWrites: Bool {
        return uncommittedChangeEvent != nil
    }

    init(docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization>,
         namespace: MongoNamespace,
         documentId: AnyBSONValue,
         errorListener: FatalErrorListener?) {
        self.docsColl = docsColl
        self.namespace = namespace
        self.documentId = documentId
        self._uncommittedChangeEvent = nil
        self._lastResolution = 0
        self._lastKnownRemoteVersion = nil
        self._isStale = false
        self._isPaused = false
        self.errorListener = errorListener
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        // verify schema version
        let schemaVersion = try values.decode(Int32.self, forKey: .schemaVersion)
        if schemaVersion != 1 {
            throw DataSynchronizerError.decodingError(
                "unexpected schema version \(schemaVersion) for CoreDocumentSynchronization")
        }

        self.namespace = try values.decode(MongoNamespace.self, forKey: .namespace)

        if let lastKnownRemoteVersion =
            try values.decodeIfPresent(Document.self, forKey: .lastKnownRemoteVersion) {
            self._lastKnownRemoteVersion = lastKnownRemoteVersion
        }

        if let eventBin = try values.decodeIfPresent(Binary.self, forKey: .uncommittedChangeEvent) {
            let eventDocument = Document.init(fromBSON: eventBin.data)

            self._uncommittedChangeEvent =
                try BSONDecoder().decode(ChangeEvent.self, from: eventDocument)
        }

        self.documentId = try values.decode(AnyBSONValue.self, forKey: .documentId)
        self._lastResolution = try values.decode(Int64.self, forKey: .lastResolution)
        self._isStale = try values.decode(Bool.self, forKey: .isStale)
        self._isPaused = try values.decode(Bool.self, forKey: .isPaused)
        self.docsColl = try values.decode(ThreadSafeMongoCollection.self, forKey: .docsColl)
    }

    func encode(to encoder: Encoder) throws {
        docLock.assertLocked()
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(documentId, forKey: .documentId)

        // verify schema version
        try container.encode(1 as Int32, forKey: .schemaVersion)

        try container.encode(namespace, forKey: .namespace)
        try container.encode(_lastResolution, forKey: .lastResolution)

        if let lastKnownRemoteVersion = _lastKnownRemoteVersion {
            try container.encode(lastKnownRemoteVersion, forKey: .lastKnownRemoteVersion)
        }

        if let uncommittedChangeEvent = _uncommittedChangeEvent {
            let changeEventDoc = try BSONEncoder().encode(uncommittedChangeEvent)
            try container.encode(
                Binary.init(data: changeEventDoc.rawBSON, subtype: Binary.Subtype.generic),
                forKey: .uncommittedChangeEvent
            )
        }

        try container.encode(_isStale, forKey: .isStale)
        try container.encode(_isPaused, forKey: .isPaused)
        try container.encode(docsColl, forKey: .docsColl)
    }

    /**
     Sets that there are some pending writes that occurred at a time for an associated
     locally emitted change event. This variant maintains the last version set.

     - parameter atTime: the time at which the write occurred.
     - parameter changeEvent: the description of the write/change.
     */
    func setSomePendingWrites(atTime: Int64,
                              changeEvent: ChangeEvent<Document>) throws {
        // if we were frozen
        if self.isPaused {
            // unfreeze the document due to the local write
            self.isPaused = false
            // and now the unfrozen document is now stale
            self.isStale = true
        }

        try docLock.write {
            self.uncommittedChangeEvent = CoreDocumentSynchronization.coalesceChangeEvents(
                lastUncommittedChangeEvent: self._uncommittedChangeEvent,
                newestChangeEvent: changeEvent)
            self.lastResolution = atTime
            try docsColl.replaceOne(filter: docConfigFilter(forNamespace: namespace,
                                                            withDocumentId: documentId),
                                    replacement: self)
        }
    }

    /**
     Sets that there are some pending writes that occurred at a time for an associated
     locally emitted change event. This variant updates the last version set.

     - parameter atTime:      the time at which the write occurred.
     - parameter atVersion:   the version for which the write occurred.
     - parameter changeEvent: the description of the write/change.
     */
    func setSomePendingWrites(atTime: Int64,
                              atVersion: Document?,
                              changeEvent: ChangeEvent<Document>) throws {
        try docLock.write {
            self.uncommittedChangeEvent = changeEvent
            self.lastResolution = atTime
            self.lastKnownRemoteVersion = atVersion

            try docsColl.replaceOne(filter: docConfigFilter(forNamespace: namespace,
                                                            withDocumentId: documentId),
                                    replacement: self)
        }
    }

    /**
     Sets that the pending writes are complete for a given version.
     This will reset the state of the config to reflect its latest state,
     but with no pending updates.

     - parameter atVersion: the version for which the write as completed on
     */
    func setPendingWritesComplete(atVersion: Document?) throws {
        try docLock.write {
            self.uncommittedChangeEvent = nil
            self.lastKnownRemoteVersion = atVersion

            try docsColl.replaceOne(filter: docConfigFilter(forNamespace: namespace,
                                                            withDocumentId: documentId),
                                    replacement: self)
        }
    }

    /**
     Whether or not the last known remote version is equal to a given version.
     - parameter versionInfo: A version to compare against the last known remote version
     - returns: true if this config has the given committed version, false if not
     */
    public func hasCommittedVersion(versionInfo: DocumentVersionInfo?) throws -> Bool {
        return try docLock.read {
            let localVersionInfo = try DocumentVersionInfo.fromVersionDoc(versionDoc: self.lastKnownRemoteVersion)
            if let newVersion = versionInfo?.version, let localVersion = localVersionInfo.version {
                return (newVersion.syncProtocolVersion == localVersion.syncProtocolVersion)
                    && (newVersion.instanceId == localVersion.instanceId)
                    && (newVersion.versionCounter <= localVersion.versionCounter)
            }

            return false
        }
    }

    internal static func filter(forNamespace namespace: MongoNamespace) -> Document {
        guard let namespaceDoc = try? BSONEncoder().encode(namespace) else {
            return [CodingKeys.namespace.rawValue: BSONNull()]
        }
        return [CodingKeys.namespace.rawValue: namespaceDoc]
    }

    /**
     Possibly coalesces the newest change event to match the user's original intent. For example,
     an unsynchronized insert and update is still an insert.

     - parameter lastUncommittedChangeEvent: the last change event known about for a document.
     - parameter newestChangeEvent:          the newest change event known about for a document.
     - returns: the possibly coalesced change event.
     */
    internal static func coalesceChangeEvents(lastUncommittedChangeEvent: ChangeEvent<Document>?,
                                              newestChangeEvent: ChangeEvent<Document>) -> ChangeEvent<Document> {
        guard let lastUncommittedChangeEvent = lastUncommittedChangeEvent else {
            return newestChangeEvent
        }

        switch lastUncommittedChangeEvent.operationType {
        case .insert:
            switch newestChangeEvent.operationType {
                // Coalesce replaces/updates to inserts since we believe at some point a document did not
                // exist remotely and that this replace or update should really be an insert if we are
            // still in an uncommitted state.
            case .update, .replace:
                return ChangeEvent<Document>(id: newestChangeEvent.id,
                                             operationType: .insert,
                                             fullDocument: newestChangeEvent.fullDocument,
                                             ns: newestChangeEvent.ns,
                                             documentKey: newestChangeEvent.documentKey,
                                             updateDescription: nil,
                                             hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites)
            default: break
            }
        case .delete:
            switch newestChangeEvent.operationType {
            // Coalesce inserts to replaces since we believe at some point a document existed
            // remotely and that this insert should really be an replace if we are still in an
            // uncommitted state.
            case .insert:
                return ChangeEvent(id: newestChangeEvent.id,
                                   operationType: .replace,
                                   fullDocument: newestChangeEvent.fullDocument,
                                   ns: newestChangeEvent.ns,
                                   documentKey: newestChangeEvent.documentKey,
                                   updateDescription: nil,
                                   hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites)
            default:
                break
            }
        default:
            break
        }
        return newestChangeEvent
    }

    static func == (lhs: CoreDocumentSynchronization, rhs: CoreDocumentSynchronization) -> Bool {
        return lhs.documentId.value.bsonEquals(rhs.documentId.value)
    }

    func hash(into hasher: inout Hasher) {
        self.documentId.hash(into: &hasher)
    }
}
