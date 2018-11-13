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
internal func docFilter(forNamespace namespace: MongoNamespace,
                        withDocumentId documentId: AnyBSONValue) -> Document {
    return [
        CoreDocumentSynchronization.Config.CodingKeys.namespace.rawValue: namespace.description,
        CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue: documentId.value
    ]
}

/**
 The synchronization portal for this document.

 Document configurations contain information about a synchronized document.

 Configurations are stored both persistently and in memory, and should
 always be in sync.
 */
internal struct CoreDocumentSynchronization: Hashable {
    /// The actual configuration to be persisted for this document.
    class Config: Codable, Hashable {
        enum CodingKeys: String, CodingKey {
            case namespace, documentId, lastUncommittedChangeEvent,
            lastResolution, lastKnownRemoteVersion, isStale, isPaused
        }

        let namespace: MongoNamespace
        let documentId: HashableBSONValue
        fileprivate var lastUncommittedChangeEvent: ChangeEvent<Document>?
        fileprivate var lastResolution: TimeInterval
        fileprivate var lastKnownRemoteVersion: Document?
        fileprivate var isStale: Bool
        fileprivate var isPaused: Bool

        init(namespace: MongoNamespace,
             documentId: HashableBSONValue,
             lastUncommittedChangeEvent: ChangeEvent<Document>?,
             lastResolution: TimeInterval,
             lastKnownRemoteVersion: Document?,
             isStale: Bool,
             isPaused: Bool) {
            self.namespace = namespace
            self.documentId = documentId
            self.lastUncommittedChangeEvent = lastUncommittedChangeEvent
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
    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
    /// Standard read-write lock.
    private let docLock: ReadWriteLock = ReadWriteLock()
    /// The configuration for this document.
    private(set) var config: Config
    /// The namespace this document is stored in.
    var namespace: MongoNamespace { get { return config.namespace } }
    /// The id of this document.
    var documentId: AnyBSONValue { get { return config.documentId.bsonValue } }

    /// The most recent pending change event
    var lastUncommittedChangeEvent: ChangeEvent<Document>? {
        get {
            docLock.readLock()
            defer { docLock.unlock() }
            return config.lastUncommittedChangeEvent
        }
        set(value) {
            self.config.lastUncommittedChangeEvent = value
        }
    }

    /// The last time a pending write has been triggered.
    var lastResolution: TimeInterval {
        get {
            docLock.readLock()
            defer { docLock.unlock() }
            return self.config.lastResolution
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            self.config.lastResolution = value
        }
    }

    /// The last known remote version.
    var lastKnownRemoteVersion: Document? {
        get { return self.config.lastKnownRemoteVersion }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            self.config.lastKnownRemoteVersion = value
        }
    }

    /// Whether or not this document has gone stale.
    var isStale: Bool {
        get {
            docLock.readLock()
            defer { docLock.unlock() }
            var filter = docFilter(forNamespace: namespace, withDocumentId: documentId)
            try! filter.merge([Config.CodingKeys.isStale.rawValue: true])
            let count = try! docsColl.count(filter)
            return count == 1
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            let _ = try! docsColl.updateOne(
                filter: docFilter(forNamespace: namespace, withDocumentId: documentId),
                update: ["$set": [Config.CodingKeys.isStale.rawValue: value] as Document])
            self.config.isStale = value
        }
    }

    /// Whether or not this document has been paused due to an error.
    var isPaused: Bool {
        get {
            docLock.readLock()
            defer { docLock.unlock() }
            return config.isPaused
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            let _ = try! docsColl.updateOne(
                filter: docFilter(forNamespace: namespace,
                                  withDocumentId: documentId),
                update: [ "$set": [ Config.CodingKeys.isPaused.rawValue : value ] as Document
                ])
            config.isPaused = value
        }
    }

    /// Whether or not there is a pending write for this document.
    var hasUncommittedWrites: Bool {
        get {
            return lastUncommittedChangeEvent != nil
        }
    }

    init(docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         namespace: MongoNamespace,
         documentId: AnyBSONValue) {
        self.docsColl = docsColl
        self.config = Config.init(namespace: namespace,
                                  documentId: HashableBSONValue.init(documentId),
                                  lastUncommittedChangeEvent: nil,
                                  lastResolution: -1,
                                  lastKnownRemoteVersion: nil,
                                  isStale: false,
                                  isPaused: false)
    }

    init(docsColl: MongoCollection<CoreDocumentSynchronization.Config>,
         config: inout Config) {
        self.docsColl = docsColl
        self.config = config
    }

    /**
     Sets that there are some pending writes that occurred at a time for an associated
     locally emitted change event. This variant maintains the last version set.

     - parameter atTime: the time at which the write occurred.
     - parameter changeEvent: the description of the write/change.
     */
    mutating func setSomePendingWrites(atTime: TimeInterval,
                                       changeEvent: ChangeEvent<Document>) {
        // if we were frozen
        if (isPaused) {
            // unfreeze the document due to the local write
            isPaused = false
            // and now the unfrozen document is now stale
            isStale = true
        }

        docLock.writeLock()
        defer { docLock.unlock() }
        self.lastUncommittedChangeEvent = CoreDocumentSynchronization.coalesceChangeEvents(
            lastUncommittedChangeEvent: self.lastUncommittedChangeEvent,
            newestChangeEvent: changeEvent)
        self.lastResolution = atTime
        let _ = try? docsColl.replaceOne(filter: docFilter(forNamespace: namespace,
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
    mutating func setSomePendingWrites(atTime: TimeInterval,
                                       atVersion: Document,
                                       changeEvent: ChangeEvent<Document>) {
        docLock.writeLock()
        defer { docLock.unlock() }

        self.lastUncommittedChangeEvent = changeEvent
        self.lastResolution = atTime
        self.lastKnownRemoteVersion = atVersion

        let _ = try? docsColl.replaceOne(
            filter: docFilter(forNamespace: namespace,
                              withDocumentId: documentId),
            replacement: self.config)
    }

    /**
     Sets that the pending writes are complete for a given version.
     This will reset the state of the config to reflect its latest state,
     but with no pending updates.

     - parameter atVersion: the version for which the write as completed on
     */
    mutating func setPendingWritesComplete(atVersion: Document) {
        docLock.writeLock()
        defer { docLock.unlock() }
        self.lastUncommittedChangeEvent = nil
        self.lastKnownRemoteVersion = atVersion

        let _ = try? docsColl.replaceOne(
            filter: docFilter(forNamespace: namespace,
                              withDocumentId: documentId),
            replacement: self.config)
    }

    /**
     Whether or not the last known remote version is equal to a given version.
     - parameter versionInfo: A version to compare against the last known remote version
     - returns: true if this config has the given committed version, false if not
     */
    public func hasCommittedVersion(versionInfo: DocumentVersionInfo) -> Bool {
        docLock.readLock()
        defer { docLock.unlock() }
        let localVersionInfo = DocumentVersionInfo.fromVersionDoc(versionDoc: self.lastKnownRemoteVersion)
        return ((versionInfo.hasVersion && localVersionInfo.hasVersion
            && (versionInfo.version?.syncProtocolVersion
                == localVersionInfo.version?.syncProtocolVersion)
            && (versionInfo.version?.instanceId
                == localVersionInfo.version?.instanceId))
            && (versionInfo.version?.versionCounter ?? 0
                <= localVersionInfo.version?.versionCounter ?? 0))
    }

    func hash(into hasher: inout Hasher) {
        self.config.hash(into: &hasher)
    }

    internal static func filter(forNamespace namespace: MongoNamespace) -> Document {
        return [CoreDocumentSynchronization.Config.CodingKeys.namespace.rawValue: namespace.description]
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
