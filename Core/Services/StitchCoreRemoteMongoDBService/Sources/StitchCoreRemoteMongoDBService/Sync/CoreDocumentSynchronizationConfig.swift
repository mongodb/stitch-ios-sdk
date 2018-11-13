import Foundation
import MongoMobile
import MongoSwift

private func getDocFilter(namespace: MongoNamespace, documentId: AnyBSONValue) -> Document {
    return [
        CoreDocumentSynchronization.Config.CodingKeys.namespace.rawValue: namespace.description,
        CoreDocumentSynchronization.Config.CodingKeys.documentId.rawValue: documentId.value
    ]
}

struct CoreDocumentSynchronization: Hashable {
    struct Config: Codable, Hashable {
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

        static func == (lhs: CoreDocumentSynchronization.Config,
                        rhs: CoreDocumentSynchronization.Config) -> Bool {
            return lhs.documentId == rhs.documentId
        }

        func hash(into hasher: inout Hasher) {
            documentId.hash(into: &hasher)
        }
    }

    private let docsColl: MongoCollection<CoreDocumentSynchronization.Config>
    private let docLock: ReadWriteLock = ReadWriteLock()
    private(set) var config: Config

    var namespace: MongoNamespace { get { return config.namespace } }
    var documentId: AnyBSONValue { get { return config.documentId.bsonValue } }
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
    var lastKnownRemoteVersion: Document? {
        get { return self.config.lastKnownRemoteVersion }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            self.config.lastKnownRemoteVersion = value
        }
    }

    /// whether or not this document has gone stale
    var isStale: Bool {
        get {
            docLock.readLock()
            defer { docLock.unlock() }
            var filter = getDocFilter(namespace: namespace, documentId: documentId)
            try! filter.merge([Config.CodingKeys.isStale.rawValue: true])
            let count = try! docsColl.count(filter)
            return count == 1
        }
        set(value) {
            docLock.writeLock()
            defer { docLock.unlock() }
            let _ = try! docsColl.updateOne(
                filter: getDocFilter(namespace: namespace, documentId: documentId),
                update: ["$set": [Config.CodingKeys.isStale.rawValue: value] as Document])
            self.config.isStale = value
        }
    }

    /// whether or not this document has been paused due to an error
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
                filter: getDocFilter(namespace: namespace,
                                     documentId: documentId),
                update: [ "$set": [ Config.CodingKeys.isPaused.rawValue : value ] as Document
                ])
            config.isPaused = value
        }
    }

    /// whether or not there is a pending write for this document
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
         config: Config) {
        self.docsColl = docsColl
        self.config = config
    }

    /**
     * Sets that there are some pending writes that occurred at a time for an associated
     * locally emitted change event. This variant maintains the last version set.
     *
     * @param atTime      the time at which the write occurred.
     * @param changeEvent the description of the write/change.
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
        let _ = try? docsColl.replaceOne(filter: getDocFilter(namespace: namespace,
                                                              documentId: documentId),
                                         replacement: self.config)
    }

    /**
     * Sets that there are some pending writes that occurred at a time for an associated
     * locally emitted change event. This variant updates the last version set.
     *
     * @param atTime      the time at which the write occurred.
     * @param atVersion   the version for which the write occurred.
     * @param changeEvent the description of the write/change.
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
            filter: getDocFilter(namespace: namespace,
                                 documentId: documentId),
            replacement: self.config)
    }

    mutating func setPendingWritesComplete(atVersion: Document) {
        docLock.writeLock()
        defer { docLock.unlock() }
        self.lastUncommittedChangeEvent = nil
        self.lastKnownRemoteVersion = atVersion

        let _ = try? docsColl.replaceOne(
            filter: getDocFilter(namespace: namespace,
                                 documentId: documentId),
            replacement: self.config)
    }

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
     * Possibly coalesces the newest change event to match the user's original intent. For example,
     * an unsynchronized insert and update is still an insert.
     *
     * - parameter lastUncommittedChangeEvent: the last change event known about for a document.
     * - parameter newestChangeEvent:          the newest change event known about for a document.
     * - returns: the possibly coalesced change event.
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
                    hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites
                )
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
                    hasUncommittedWrites: newestChangeEvent.hasUncommittedWrites
                );
            default:
                break;
            }
            break;
        default:
            break;
        }
        return newestChangeEvent
    }

    static func == (lhs: CoreDocumentSynchronization, rhs: CoreDocumentSynchronization) -> Bool {
        return lhs.config == rhs.config
    }
}
