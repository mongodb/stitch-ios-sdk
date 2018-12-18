import Foundation
import MongoMobile
import MongoSwift

/**
 Returns a query filter for a document with a given
 namespace and documentId.
 - parameter namespace: the namespace the document is in
 - parameter documentId: the id of the document
 - returns: a query filter to find a document
 */
internal func docConfigFilter(forNamespace namespace: MongoNamespace,
                              withDocumentId documentId: AnyBSONValue) -> Document {
    return [
        CoreDocumentSynchronization.Config.CodingKeys.namespace.rawValue:
            try! BSONEncoder().encode(namespace),
        CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue: documentId.value
    ]
}

/**
 The synchronization class for this document.

 Document configurations contain information about a synchronized document.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal class CoreDocumentSynchronization: Hashable {
    /// The actual configuration to be persisted for this document.
    class Config: Codable, Hashable {
        enum CodingKeys: String, CodingKey {
            // These are snake_case because we are trying to keep the internal
            // representation consistent across platforms
            case namespace = "namespace",
            documentId = "document_id", uncommittedChangeEvent = "last_uncommitted_change_event",
            lastResolution = "last_resolution", lastKnownRemoteVersion = "last_known_remote_version",
            isStale = "is_stale", isPaused = "is_paused", schemaVersion = "schema_version"
        }

        let namespace: MongoNamespace
        let documentId: HashableBSONValue
        fileprivate(set) internal var uncommittedChangeEvent: ChangeEvent<Document>?
        fileprivate var lastResolution: Int64
        fileprivate var lastKnownRemoteVersion: Document?
        fileprivate var isStale: Bool
        fileprivate var isPaused: Bool

        // from BSON document
        required init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            // verify schema version
            let schemaVersion = try values.decode(Int32.self, forKey: .schemaVersion)
            if schemaVersion != 1 {
                throw DataSynchronizerError(
                    "unexpected schema version \(schemaVersion) for CoreDocumentSynchronization.Config"
                )
            }

            self.namespace = try values.decode(MongoNamespace.self, forKey: .namespace)

            if let lastKnownRemoteVersion =
                try values.decodeIfPresent(Document.self, forKey: .lastKnownRemoteVersion) {
                self.lastKnownRemoteVersion = lastKnownRemoteVersion
            }

            if let eventBin = try values.decodeIfPresent(Binary.self, forKey: .uncommittedChangeEvent) {
                let eventDocument = Document.init(fromBSON: eventBin.data)

                self.uncommittedChangeEvent =
                    try BSONDecoder().decode(ChangeEvent.self, from: eventDocument)
            }

            self.documentId = try values.decode(HashableBSONValue.self, forKey: .documentId)
            self.lastResolution = try values.decode(Int64.self, forKey: .lastResolution)
            self.isStale = try values.decode(Bool.self, forKey: .isStale)
            self.isPaused = try values.decode(Bool.self, forKey: .isPaused)
        }

        // to BSON document
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(documentId, forKey: .documentId)

            // verify schema version
            try container.encode(1 as Int32, forKey: .schemaVersion)

            try container.encode(namespace, forKey: .namespace)
            try container.encode(lastResolution, forKey: .lastResolution)

            if let lastKnownRemoteVersion = lastKnownRemoteVersion {
                try container.encode(lastKnownRemoteVersion, forKey: .lastKnownRemoteVersion)
            }

            if let uncommittedChangeEvent = uncommittedChangeEvent {
                let changeEventDoc = try BSONEncoder().encode(uncommittedChangeEvent)
                // TODO: This may put the doc above the 16MiB but ignore for now.
                try container.encode(
                    Binary.init(data: changeEventDoc.rawBSON, subtype: Binary.Subtype.generic),
                    forKey: .uncommittedChangeEvent
                )
            }

            try container.encode(isStale, forKey: .isStale)
            try container.encode(isPaused, forKey: .isPaused)
        }

        required init(namespace: MongoNamespace,
             documentId: HashableBSONValue,
             lastUncommittedChangeEvent: ChangeEvent<Document>?,
             lastResolution: Int64,
             lastKnownRemoteVersion: Document?,
             isStale: Bool,
             isPaused: Bool) {
            self.namespace = namespace
            self.documentId = documentId
            self.uncommittedChangeEvent = lastUncommittedChangeEvent
            self.lastResolution = lastResolution
            self.lastKnownRemoteVersion = lastKnownRemoteVersion
            self.isStale = isStale
            self.isPaused = isPaused
        }
        
        static func == (lhs: CoreDocumentSynchronization.Config,
                        rhs: CoreDocumentSynchronization.Config) -> Bool {
            return lhs.documentId == rhs.documentId
        }

        func hash(into hasher: inout Hasher) {
            documentId.hash(into: &hasher)
        }


    }

    /// The collection we are storing document configs in.
    private let docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization.Config>
    /// Standard read-write lock.
    private let docLock: ReadWriteLock
    /// The error listener to propogate errors to.
    private weak var errorListener: FatalErrorListener?
    /// The configuration for this document.
    private(set) var config: Config
    /// The namespace this document is stored in.
    var namespace: MongoNamespace { get { return config.namespace } }
    /// The id of this document.
    var documentId: AnyBSONValue { get { return config.documentId.bsonValue } }

    /// The most recent pending change event
    var uncommittedChangeEvent: ChangeEvent<Document>? {
        get {
            docLock.readLock()
            defer { docLock.unlock(for: .reading) }
            return config.uncommittedChangeEvent
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock(for: .writing) }
            // the write lock should be held elsewhere
            // when setting this value
            self.config.uncommittedChangeEvent = value
        }
    }

    /// The last time a pending write has been triggered.
    var lastResolution: Int64 {
        get {
            docLock.readLock()
            defer { docLock.unlock(for: .reading) }
            return self.config.lastResolution
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock(for: .writing) }
            self.config.lastResolution = value
        }
    }

    /// The last known remote version.
    var lastKnownRemoteVersion: Document? {
        get {
            docLock.readLock()
            defer { docLock.unlock(for: .reading) }
            return self.config.lastKnownRemoteVersion
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock(for: .writing) }
            self.config.lastKnownRemoteVersion = value
        }
    }

    /// Whether or not this document has gone stale.
    var isStale: Bool {
        get {
            docLock.readLock()
            defer { docLock.unlock(for: .reading) }
            var filter = docConfigFilter(forNamespace: namespace, withDocumentId: documentId)
            do {
                try filter.merge([Config.CodingKeys.isStale.rawValue: true])
                let count = try docsColl.count(filter)
                return count == 1
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
                return self.config.isStale
            }
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock(for: .writing) }
            do {
                try docsColl.updateOne(
                    filter: docConfigFilter(forNamespace: namespace, withDocumentId: documentId),
                    update: ["$set": [Config.CodingKeys.isStale.rawValue: value] as Document])
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
            }
            self.config.isStale = value
        }
    }

    /// Whether or not this document has been paused due to an error.
    var isPaused: Bool {
        get {
            docLock.readLock()
            defer { docLock.unlock(for: .reading) }
            return config.isPaused
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock(for: .writing) }
            do {
                try docsColl.updateOne(
                    filter: docConfigFilter(forNamespace: namespace,
                                            withDocumentId: documentId),
                    update: [ "$set": [ Config.CodingKeys.isPaused.rawValue : value ] as Document
                    ])
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId.value, in: namespace)
            }
            config.isPaused = value
        }
    }

    /// Whether or not there is a pending write for this document.
    var hasUncommittedWrites: Bool {
        get {
            return uncommittedChangeEvent != nil
        }
    }

    init(docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization.Config>,
         namespace: MongoNamespace,
         documentId: AnyBSONValue,
         errorListener: FatalErrorListener?) throws {
        self.docsColl = docsColl
        self.config = Config.init(namespace: namespace,
                                  documentId: HashableBSONValue.init(documentId),
                                  lastUncommittedChangeEvent: nil,
                                  lastResolution: 0,
                                  lastKnownRemoteVersion: nil,
                                  isStale: false,
                                  isPaused: false)
        self.errorListener = errorListener
        try self.docLock = ReadWriteLock()
    }

    init(docsColl: ThreadSafeMongoCollection<CoreDocumentSynchronization.Config>,
         config: inout Config,
         errorListener: FatalErrorListener?) throws {
        self.docsColl = docsColl
        self.config = config
        self.errorListener = errorListener
        try self.docLock = ReadWriteLock()
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
        if (isPaused) {
            // unfreeze the document due to the local write
            isPaused = false
            // and now the unfrozen document is now stale
            isStale = true
        }

        docLock.writeLock()
        defer { docLock.unlock(for: .writing) }
        self.uncommittedChangeEvent = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: self.uncommittedChangeEvent,
            newestChangeEvent: changeEvent)
        self.lastResolution = atTime
        try docsColl.replaceOne(filter: docConfigFilter(forNamespace: namespace,
                                                        withDocumentId: documentId),
                                replacement: self.config)
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
        docLock.writeLock()
        defer { docLock.unlock(for: .writing) }

        self.uncommittedChangeEvent = changeEvent
        self.lastResolution = atTime
        self.lastKnownRemoteVersion = atVersion

        try docsColl.replaceOne(
            filter: docConfigFilter(forNamespace: namespace,
                                    withDocumentId: documentId),
            replacement: self.config)
    }

    /**
     Sets that the pending writes are complete for a given version.
     This will reset the state of the config to reflect its latest state,
     but with no pending updates.

     - parameter atVersion: the version for which the write as completed on
     */
    func setPendingWritesComplete(atVersion: Document?) throws {
        docLock.writeLock()
        defer { docLock.unlock(for: .writing) }
        self.uncommittedChangeEvent = nil
        self.lastKnownRemoteVersion = atVersion

        try docsColl.replaceOne(
            filter: docConfigFilter(forNamespace: namespace,
                                    withDocumentId: documentId),
            replacement: self.config)
    }

    /**
     Whether or not the last known remote version is equal to a given version.
     - parameter versionInfo: A version to compare against the last known remote version
     - returns: true if this config has the given committed version, false if not
     */
    public func hasCommittedVersion(versionInfo: DocumentVersionInfo?) throws -> Bool {
        docLock.readLock()
        defer { docLock.unlock(for: .reading) }
        let localVersionInfo = try DocumentVersionInfo.fromVersionDoc(versionDoc: self.lastKnownRemoteVersion)
        if let newVersion = versionInfo?.version, let localVersion = localVersionInfo.version {
            return (newVersion.syncProtocolVersion == localVersion.syncProtocolVersion)
                && (newVersion.instanceId == localVersion.instanceId)
                && (newVersion.versionCounter <= localVersion.versionCounter)
        }

        return false
    }

    func hash(into hasher: inout Hasher) {
        self.config.hash(into: &hasher)
    }

    internal static func filter(forNamespace namespace: MongoNamespace) -> Document {
        return [CoreDocumentSynchronization.Config.CodingKeys.namespace.rawValue: try! BSONEncoder().encode(namespace)]
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
                return ChangeEvent<Document>(
                    id: newestChangeEvent.id,
                    operationType: .insert,
                    fullDocument: newestChangeEvent.fullDocument,
                    ns: newestChangeEvent.ns,
                    documentKey: newestChangeEvent.documentKey,
                    updateDescription: nil,
                    hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites)
            default: break
            }
            break
        case .delete:
            switch newestChangeEvent.operationType {
            // Coalesce inserts to replaces since we believe at some point a document existed
            // remotely and that this insert should really be an replace if we are still in an
            // uncommitted state.
            case .insert:
                return ChangeEvent(
                    id: newestChangeEvent.id,
                    operationType: .replace,
                    fullDocument: newestChangeEvent.fullDocument,
                    ns: newestChangeEvent.ns,
                    documentKey: newestChangeEvent.documentKey,
                    updateDescription: nil,
                    hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites)
            default:
                break
            }
            break
        default:
            break
        }
        return newestChangeEvent
    }

    static func == (lhs: CoreDocumentSynchronization, rhs: CoreDocumentSynchronization) -> Bool {
        return lhs.config == rhs.config
    }
}
