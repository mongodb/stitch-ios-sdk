// These linter exceptions should eventually go away, but they would require major refactoring.
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
// swiftlint:disable file_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length
// swiftlint:disable function_parameter_count
import Foundation
import MongoSwift
import MongoMobile
import StitchCoreSDK

private let idField = "_id"

/**
 DataSynchronizer handles the bidirectional synchronization of documents between a local MongoDB
 and a remote MongoDB (via Stitch). It also expose CRUD operations to interact with synchronized
 documents.
 */
public class DataSynchronizer: NetworkStateDelegate, FatalErrorListener {
    /// The amount of time to sleep between sync passes in a non-error state.
    fileprivate static let shortSleepSeconds: UInt32 = 1
    /// The amount of time to sleep between sync passes in an error-state.
    fileprivate static let longSleepSeconds: UInt32 = 5
    /// The current sync protocol version
    public static let syncProtocolVersion: Int32 = 1

    /// The unique instance key for this DataSynchronizer
    private let instanceKey: String!
    /// The associated service client
    private let service: CoreStitchServiceClient
    /// The associated remote client
    private let remoteClient: CoreRemoteMongoClient
    private var appInfo: StitchAppClientInfo!
    /// Network monitor that receives to network state
    private var networkMonitor: NetworkMonitor!
    /// Auth monitor that receives auth state
    private var authMonitor: AuthMonitor!
    /// Thread safe MongoClient
    internal var localClient: ThreadSafeMongoClient!
    /// Database to manage our configurations
    private var configDb: ThreadSafeMongoDatabase!
    /// The collection to store the configuration for this instance in
    private var instancesColl: ThreadSafeMongoCollection<InstanceSynchronization>!
    /// The configuration for this sync instance
    internal var syncConfig: InstanceSynchronization!

    // this is not a normal delegate pattern, so this is okay
    // swiftlint:disable weak_delegate
    internal var instanceChangeStreamDelegate: InstanceChangeStreamDelegate!
    // swiftlint:enable weak_delegate

    /// Whether or not the DataSynchronizer has been configured
    private(set) var isConfigured = false
    /// Whether or not the sync thread is enabled
    var isSyncThreadEnabled = true

    /// RW lock for the synchronizer
    private let syncLock: ReadWriteLock
    /// Local logger
    private lazy var logger: Log! = Log.init(tag: "dataSynchronizer-\(self.instanceKey!)")
    /// Label for dispatch queue log messages
    private lazy var eventDispatchQueueLabel = "eventEmission-\(self.instanceKey!)"
    /// Dispatch queue for one-off events
    private lazy var eventDispatchQueue = DispatchQueue.init(
        label: eventDispatchQueueLabel,
        qos: .default)
    /// Shared dispatcher for change events
    private lazy var eventDispatcher = EventDispatcher(eventDispatchQueue, logger, service)
    /// Dispatch queue for long running sync loop
    private lazy var syncDispatchQueue = DispatchQueue.init(
        label: "synchronizer-\(self.instanceKey!)",
        qos: .background,
        autoreleaseFrequency: .inherit)
    /// The current work item running the sync loop
    private var syncWorkItem: DispatchWorkItem?
    /// The current work item running sync initialization (and possibly recovery on the initial init)
    private var initWorkItem: DispatchWorkItem?
    /// The user's error listener
    private var errorListener: ErrorListener?
    /// Current sync pass iteration
    internal var logicalT: Int64 = 0
    /// Whether or not the sync loop is running
    var isRunning: Bool {
        return syncLock.read {
            return syncWorkItem != nil && syncWorkItem?.isCancelled == false
        }
    }

    private let operationsGroup = BlockableDispatchGroup()

    public init(instanceKey: String,
                service: CoreStitchServiceClient,
                remoteClient: CoreRemoteMongoClient,
                appInfo: StitchAppClientInfo) throws {
        self.instanceKey = instanceKey
        self.service = service
        self.remoteClient = remoteClient
        self.syncLock = ReadWriteLock(label: "sync_\(service.serviceName ?? "mongodb-atlas")")

        self.appInfo = appInfo
        self.networkMonitor = appInfo.networkMonitor
        self.authMonitor = appInfo.authMonitor

        self.localClient = try ThreadSafeMongoClient(withAppInfo: appInfo)

        self.networkMonitor.add(networkStateDelegate: self)

        self.initWorkItem = DispatchWorkItem {
            do {
                try self.initialize()
                try self.recover()
            } catch {
                // notify the fatal error listener about a fatal error with sync initialization
                self.on(
                    error: StitchError.clientError(
                        withClientErrorCode: StitchClientErrorCode.syncInitializationError(withError: error)
                    ),
                    forDocumentId: nil,
                    in: nil
                )
            }
        }
        syncDispatchQueue.async(execute: self.initWorkItem!)
    }

    private func initialize() throws {
        self.configDb = localClient.db(DataSynchronizer.localConfigDBName(withInstanceKey: instanceKey))

        self.instancesColl = configDb.collection("instances",
                                                 withType: InstanceSynchronization.self)

        if try instancesColl.count() == 0 {
            self.syncConfig = try InstanceSynchronization(configDb: configDb,
                                                          errorListener: nil)
            try instancesColl.insertOne(self.syncConfig)
        } else {
            guard let config = try instancesColl.find().next() else {
                throw StitchError.clientError(
                    withClientErrorCode: StitchClientErrorCode.couldNotLoadSyncInfo)
            }

            self.syncConfig = config
        }

        self.instanceChangeStreamDelegate = InstanceChangeStreamDelegate(
            instanceConfig: syncConfig,
            service: service,
            networkMonitor: networkMonitor,
            authMonitor: authMonitor)
        self.syncConfig.forEach {
            self.instanceChangeStreamDelegate.append(namespace: $0.namespace)
        }
        self.syncConfig.errorListener = self

    }

    func reinitialize() {
        // can't reinitialize until we're done initializing in the first place
        self.waitUntilInitialized()

        operationsGroup.blockAndWait()
        self.initWorkItem = DispatchWorkItem {
            do {
                try self.initialize()
            } catch {
                // notify the fatal error listener about a fatal error with sync initialization
                self.on(
                    error: StitchError.clientError(
                        withClientErrorCode: StitchClientErrorCode.syncInitializationError(withError: error)
                    ),
                    forDocumentId: nil,
                    in: nil
                )
            }
            self.operationsGroup.unblock()
        }
        self.syncDispatchQueue.async(execute: self.initWorkItem!)
    }

    public func on(stateChangedFor state: NetworkState) {
        switch state {
        case .connected:
            self.start()
        case .disconnected:
            self.stop()
        }
    }

    /**
     * Recovers the state of synchronization in case a system failure happened.
     * The goal is to revert to a known, good state.
     */
    private func recover() throws {
        let nsConfigs = self.syncConfig.compactMap { $0 }

        try nsConfigs.forEach { namespaceSynchronization in
            try namespaceSynchronization.nsLock.write {
                try recoverNamespace(withConfig: namespaceSynchronization)
            }
        }
    }

    /**
     * Recovers the state of synchronization for a namespace in case a system failure happened.
     * The goal is to revert the namespace to a known, good state. This method itself is resilient
     * to failures, since it doesn't delete any documents from the undo collection until the
     * collection is in the desired state with respect to those documents.
     */
    private func recoverNamespace(withConfig nsConfig: NamespaceSynchronization) throws {
        let undoColl = undoCollection(for: nsConfig.namespace)
        let localColl = localCollection(for: nsConfig.namespace)

        // Replace local docs with undo docs. Presence of an undo doc implies we had a system failure
        // during a write. This covers updates and deletes.
        let recoveredIdsArr: [AnyBSONValue] = try undoColl.find().compactMap { undoDoc -> AnyBSONValue? in
            guard let documentId = undoDoc[idField] else {
                // this should never happen, but we'll ignore the document if it does
                return nil
            }

            let filter = [idField: documentId] as Document

            try localColl.findOneAndReplace(
                filter: filter,
                replacement: undoDoc,
                options: FindOneAndReplaceOptions.init(upsert: true)
            )

            return AnyBSONValue.init(documentId)
        }
        let recoveredIds: Set<AnyBSONValue> = Set(recoveredIdsArr)

        // If we recovered a document, but its pending writes are set to do something else, then the
        // failure occurred after the pending writes were set, but before the undo document was
        // deleted. In this case, we should restore the document to the state that the pending
        // write indicates. There is a possibility that the pending write is from before the failed
        // operation, but in that case, the findOneAndReplace or delete is a no-op since restoring
        // the document to the state of the change event would be the same as recovering the undo
        // document.
        try nsConfig.forEach { (docConfig) in
            let documentId = docConfig.documentId.value
            let filter = [idField: documentId] as Document

            guard recoveredIds.contains(docConfig.documentId) else {
                return
            }

            guard let pendingWrite = docConfig.uncommittedChangeEvent else {
                return
            }

            switch pendingWrite.operationType {
            case .insert, .replace, .update:
                guard let fullDoc = pendingWrite.fullDocument else {
                    // should not happen, but ignore the document if the event is malformed
                    break
                }
                try localColl.findOneAndReplace(
                    filter: filter,
                    replacement: fullDoc,
                    options: FindOneAndReplaceOptions(upsert: true)
                )
            case .delete:
                try localColl.deleteOne(filter)
            case .unknown:
                throw StitchError.clientError(withClientErrorCode: .unknownChangeEventType)
            }
        }

        // Delete all of our undo documents. If we've reached this point, we've recovered the local
        // collection to the state we want with respect to all of our undo documents. If we fail before
        // these deletes or while carrying out the deletes, but after recovering the documents to
        // their desired state, that's okay because the next recovery pass will be effectively a no-op
        // up to this point.
        try recoveredIdsArr.forEach({ hashableRecoveredId in
            try undoColl.deleteOne([idField: hashableRecoveredId.value])
        })

        // Find local documents for which there are no document configs and delete them. This covers
        // inserts, upserts, and desync deletes. This will occur on any recovery pass regardless of
        // the documents in the undo collection, so it's fine that we do this after deleting the undo
        // documents.
        let syncedIds = nsConfig.map { (config) -> BSONValue in
            return config.documentId.value
        }
        try localColl.deleteMany([idField: ["$nin": syncedIds] as Document])
    }

    public func configure<CH: ConflictHandler, CED: ChangeEventDelegate>(namespace: MongoNamespace,
                                                                         conflictHandler: CH,
                                                                         changeEventDelegate: CED?,
                                                                         errorListener: ErrorListener?) {
        self.waitUntilInitialized()

        self.errorListener = errorListener

        guard let nsConfig = self.syncConfig[namespace] else {
            return
        }

        syncLock.write {
            nsConfig.configure(conflictHandler: conflictHandler, changeEventDelegate: changeEventDelegate)

            self.isConfigured = true
            self.triggerListening(to: nsConfig.namespace)
        }

        // now that we are configured, start syncing
        if !isRunning {
            self.start()
        }
    }

    /**
     Reloads the synchronization config. This wipes all in-memory synchronization settings.
     */
    public func reloadConfig() throws {
        self.waitUntilInitialized()

        try syncLock.write {
            if try instancesColl.find().next() == nil {
                throw StitchError.serviceError(
                    withMessage: "expected to find instance configuration",
                    withServiceErrorCode: .unknown)
            }

            self.instanceChangeStreamDelegate = InstanceChangeStreamDelegate(
                instanceConfig: syncConfig,
                service: service,
                networkMonitor: networkMonitor,
                authMonitor: authMonitor)

            self.syncConfig = try InstanceSynchronization(configDb: configDb,
                                                          errorListener: self)
            self.isConfigured = false
        }

        self.stop()
    }

    func doSyncPass() throws -> Bool {
        guard isConfigured else {
            return false
        }

        return try syncLock.write {
            if logicalT == UInt64.max {
                logger.i("reached max logical time; resetting back to 0")
                logicalT = 0
            }
            logicalT += 1

            logger.i("t='\(logicalT)': doSyncPass START")
            guard networkMonitor.state == .connected else {
                logger.i("t='\(logicalT)': doSyncPass END - Network disconnected")
                return false
            }
            guard authMonitor.isLoggedIn else {
                logger.i("t='\(logicalT)': doSyncPass END - Logged out")
                return false
            }

            try syncRemoteToLocal()
            try syncLocalToRemote()

            logger.i("t='\(logicalT)': doSyncPass END")
            return true
        }
    }

    /**
     Synchronizes the remote state of every requested document to be synchronized with the local
     state of said documents. Utilizes change streams to get "recent" updates to documents of
     interest. Documents that are being synchronized from the first time will be fetched via a
     full document lookup. Documents that have gone stale will be updated via change events or
     latest documents with the remote. Any conflicts that occur will be resolved locally and
     later relayed remotely on a subsequent iteration of DataSynchronizer#doSyncPass.
     */
    private func syncRemoteToLocal() throws {
        logger.i("t='\(logicalT)': syncRemoteToLocal START")

        // 2. Run remote to local (R2L) sync routine
        for nsConfig in syncConfig {
            try nsConfig.nsLock.write {
                let remoteChangeEvents =
                    instanceChangeStreamDelegate[nsConfig.namespace]?.dequeueEvents() ?? [:]
                var unseenIds = nsConfig.staleDocumentIds
                var latestDocumentMap =
                    try latestStaleDocumentsFromRemote(nsConfig: nsConfig, staleIds: unseenIds)
                        .reduce(into: [AnyBSONValue: Document](), { (result, document) in
                            guard let id = document[idField] else { return }
                            result[AnyBSONValue(id)] = document
                        })

                let localSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

                // a. For each unprocessed change event
                for (id, event) in remoteChangeEvents {
                    logger.i("t='\(logicalT)': syncRemoteToLocal consuming event of type: \(event.operationType)")
                    guard let docConfig = nsConfig[id.value],
                        !docConfig.isPaused else {
                            continue
                    }

                    unseenIds.remove(id)
                    latestDocumentMap.removeValue(forKey: id)
                    try localSyncWriteModelContainer.merge(
                        syncRemoteChangeEventToLocal(nsConfig: nsConfig, docConfig: docConfig, remoteChangeEvent: event))
                }

                // For synchronized documents that had no unprocessed change event, but were marked as
                // stale, synthesize a remote replace event to replace the local stale document with the
                // latest remote copy.
                for id in unseenIds {
                    guard let docConfig = nsConfig[id.value] else {
                        // means we aren't actually synchronizing on this remote doc
                        continue
                    }

                    var isPaused: Bool = false
                    var versionOrNil: Document?
                    var hasUncommittedWrites: Bool = false
                    docConfig.docLock.read {
                        isPaused = docConfig.isPaused
                        versionOrNil = docConfig.lastKnownRemoteVersion
                        hasUncommittedWrites = docConfig.hasUncommittedWrites
                    }

                    if let doc = latestDocumentMap[id], !isPaused {
                        try localSyncWriteModelContainer.merge(
                            syncRemoteChangeEventToLocal(
                                nsConfig: nsConfig,
                                docConfig: docConfig,
                                remoteChangeEvent: ChangeEvents.changeEventForLocalReplace(
                                    namespace: nsConfig.namespace,
                                    documentId: id.value,
                                    document: doc,
                                    writePending: false)
                        ))
                    } else {
                        // For synchronized documents that had no unprocessed change event, and did not have a
                        // latest version when stale documents were queried, synthesize a remote delete event to
                        // delete the local document.
                        if versionOrNil != nil, !isPaused {
                            try localSyncWriteModelContainer.merge(
                                syncRemoteChangeEventToLocal(
                                    nsConfig: nsConfig,
                                    docConfig: docConfig,
                                    remoteChangeEvent: ChangeEvents.changeEventForLocalDelete(
                                        namespace: nsConfig.namespace,
                                        documentId: id.value,
                                        writePending: hasUncommittedWrites
                                )))
                        }
                    }
                    docConfig.isStale = false
                }

                localSyncWriteModelContainer.commitAndClear()
            }
        }

        logger.i("t='\(logicalT)': syncRemoteToLocal END")
    }

    var syncR2LCtr = 0
    private func syncRemoteChangeEventToLocal(nsConfig: NamespaceSynchronization,
                                              docConfig: CoreDocumentSynchronization,
                                              remoteChangeEvent: ChangeEvent<Document>) throws -> LocalSyncWriteModelContainer? {
        var action: SyncAction! = nil
        var message: SyncMessage! = nil
        var actionSet: Bool = false

        if docConfig.hasUncommittedWrites && docConfig.lastResolution == logicalT {
            action = .wait
            message = .simultaneousWrites
            actionSet = true
        }

        logger.d("t='\(logicalT)': \(SyncMessage.r2lMethod) ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) processing operation='\(remoteChangeEvent.operationType)'")

        let isInsert: Bool
        let isDelete: Bool
        switch remoteChangeEvent.operationType {
        case .insert:
            isInsert = true
            isDelete = false
        case .replace, .update:
            isInsert = false
            isDelete = false
        case .delete:
            isInsert = false
            isDelete = true
        default:
            isDelete = false
            isInsert = false
            action = .dropEventAndPause
            message = .unknownOptype(opType: remoteChangeEvent.operationType)
            actionSet = true
        }

        var remoteVersionInfo: DocumentVersionInfo?
        if !actionSet { // if we haven't encountered an error...
            do {
                remoteVersionInfo = try DocumentVersionInfo.getRemoteVersionInfo(
                    remoteDocument: remoteChangeEvent.fullDocument ?? [:])
            } catch {
                action = .dropEventAndDesync
                message = .cannotParseRemoteVersion
                actionSet = true
                remoteVersionInfo = nil
            }
        }

        if !actionSet { // if we haven't encountered an error...
            if let remoteVersion = remoteVersionInfo?.version,
                remoteVersion.syncProtocolVersion != DataSynchronizer.syncProtocolVersion {
                action = .dropEventAndDesync
                message = .unknownRemoteProtocolVersion(version: remoteVersion.syncProtocolVersion)
            } else {
                // sync protocol versions match
                let lastSeenVersionInfo: DocumentVersionInfo? =
                    try? DocumentVersionInfo.fromVersionDoc(versionDoc: docConfig.lastKnownRemoteVersion)

                var lastSeenHash: Int64 = docConfig.lastKnownHash
                let remoteHash: Int64
                if let fullDocument = remoteChangeEvent.fullDocument {
                    remoteHash = HashUtils.hash(doc: DataSynchronizer.sanitizeDocument(fullDocument))
                } else {
                    remoteHash = 0
                }

                if let uncommittedChangeEvent = docConfig.uncommittedChangeEvent {
                    // pending write exists
                    if isDelete {
                        let uncommittedOpType: OperationType = uncommittedChangeEvent.operationType

                        action = (uncommittedOpType == .replace || uncommittedOpType == .update) ? .conflict : .dropEvent
                        message = .pendingWriteDelete
                    } else if let lastSeenVersion = lastSeenVersionInfo?.version {
                        if lastSeenHash == 0 {
                            // do a hash calculation if local has no hash and we have a pending write
                            lastSeenHash = HashUtils.hash(doc: uncommittedChangeEvent.fullDocument)
                        }

                        if let remoteVersion = remoteVersionInfo?.version {
                            // both have versions
                            if lastSeenVersion.instanceId != remoteVersion.instanceId {
                                action = .remoteFind
                                message = .instanceIdMismatch
                            } else {
                                let remoteVersionCounter: Int64 = remoteVersion.versionCounter
                                let lastSeenVersionCounter: Int64 = lastSeenVersion.versionCounter

                                if remoteVersionCounter > lastSeenVersionCounter {
                                    action = .conflict
                                    message = .staleLocalWrite
                                } else {
                                    action = lastSeenHash != remoteHash && !isInsert ? .conflict : .dropEvent
                                    message = .staleEvent
                                }
                            }
                        } else {
                            // last seen has version, remote does not
                            action = .conflict
                            message = .pendingWriteEmptyVersion
                        }
                    } else if remoteVersionInfo?.version != nil {
                        // remote has version, last seen does not
                        action = .conflict
                        message = .pendingWriteEmptyVersion
                    } else {
                        // neither has a version
                        action = lastSeenHash != remoteHash ? .conflict : .dropEvent
                        message = .pendingWriteEmptyVersion
                    }
                } else {
                    // no pending write
                    if remoteChangeEvent.operationType == .delete {
                        action = .deleteLocal
                        message = .deleteFromRemote
                    } else {
                        if let lastSeenVersion = lastSeenVersionInfo?.version {
                            if let remoteVersion = remoteVersionInfo?.version {
                                // both have versions
                                if lastSeenVersion.syncProtocolVersion != DataSynchronizer.syncProtocolVersion {
                                    action = .deleteLocalAndDesync
                                    message = .staleProtocolVersion(version: lastSeenVersion.syncProtocolVersion)
                                } else {
                                    if lastSeenVersion.instanceId != remoteVersion.instanceId {
                                        action = .remoteFind
                                        message = .instanceIdMismatch
                                    } else {
                                        let remoteVersionCounter: Int64 = remoteVersion.versionCounter
                                        let lastSeenVersionCounter: Int64 = lastSeenVersion.versionCounter

                                        if remoteVersionCounter > lastSeenVersionCounter {
                                            action = .applyFromRemote
                                            message = .applyFromRemote
                                        } else if remoteVersionCounter == lastSeenVersionCounter
                                            && lastSeenHash != remoteHash && !isInsert {
                                            action = .applyFromRemote
                                            message = .remoteUpdateWithoutVersion
                                        } else {
                                            action = .dropEvent
                                            message = .probablyGeneratedByUs
                                        }
                                    }
                                }
                            } else {
                                // last seen has version, remote does not
                                action = lastSeenHash != remoteHash ? .applyFromRemote : .dropEvent
                                message = .emptyVersion
                            }
                        } else {
                            if remoteVersionInfo?.version != nil {
                                // remote has a version, last seen does not
                                action = lastSeenHash != remoteHash ? .applyFromRemote : .dropEvent
                                message = .emptyVersion
                            } else {
                                // neither has a version
                                action = .applyAndVersionFromRemote
                                message = .emptyVersion
                            }
                        }
                    }
                }
            }
        }
        return try enqueueAction(nsConfig: nsConfig, docConfig: docConfig, remoteChangeEvent: remoteChangeEvent, action: action,
                                 message: message, caller: SyncMessage.r2lMethod, error: nil)
    }

    private var syncL2RCtr: Int = 0
    private func syncLocalToRemote() throws {
        logger.i(
            "t='\(logicalT)': \(SyncMessage.l2rMethod) START")

        // 1. Run local to remote (L2R) sync routine
        // Search for modifications in each namespace.
        for nsConfig in syncConfig {
            try nsConfig.nsLock.write {
                let remoteColl: CoreRemoteMongoCollection<Document> = remoteCollection(for: nsConfig.namespace)
                let localSyncWriteModelContainer: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

                // a. For each document that has local writes pending
                for docConfig in nsConfig {
                    var action: SyncAction! = nil
                    var message: SyncMessage! = nil
                    var syncError: DataSynchronizerError?
                    var remoteChangeEvent: ChangeEvent<Document>?

                    var setPendingWritesComplete: Bool = false
                    var suppressLocalEvent: Bool = false

                    var nextVersion: Document?
                    try docConfig.docLock.read {
                        guard !docConfig.isPaused,
                            let localChangeEvent = docConfig.uncommittedChangeEvent else {
                                return // exit the read lock closure
                        }
                        if docConfig.lastResolution == logicalT {
                            action = .wait
                            message = .simultaneousWrites
                            suppressLocalEvent = true
                        } else {
                            // i. Retrieve the change event for this local document in the local config metadata
                            logger.i(
                                "t='\(logicalT)': \(SyncMessage.l2rMethod) ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) processing operation='\(localChangeEvent.operationType)'")

                            let localDoc = localChangeEvent.fullDocument
                            let docFilter = [idField: docConfig.documentId.value] as Document

                            // This is here as an optimization in case an op requires we look up the remote document
                            // in advance and we only want to do this once.
                            var remoteDocument: Document?
                            var remoteDocumentFetched = false

                            let localVersionInfo =
                                try DocumentVersionInfo.getLocalVersionInfo(docConfig: docConfig)

                            // ii. Check if the internal remote change stream listener has an unprocessed event for
                            //     this document.
                            if let unprocessedRemoteEvent =
                                instanceChangeStreamDelegate[nsConfig.namespace]?.unprocessedEvent(for: docConfig.documentId.value) {
                                let unprocessedEventVersionInfo: DocumentVersionInfo?
                                do {
                                    unprocessedEventVersionInfo = try DocumentVersionInfo.getRemoteVersionInfo(remoteDocument: unprocessedRemoteEvent.fullDocument ?? [:])
                                } catch {
                                    action = .dropEventAndDesync
                                    message = .cannotParseRemoteVersion
                                    unprocessedEventVersionInfo = nil
                                    suppressLocalEvent = true
                                }

                                // 1. If it does and the version info is different, record that a conflict has occurred.
                                //    Difference is determined if either the GUID is different or the version counter is
                                //    greater than the local version counter, or if both versions are empty
                                if unprocessedEventVersionInfo != nil {
                                    if let unprocessedEventVersion: DocumentVersionInfo.Version
                                        = unprocessedEventVersionInfo?.version {
                                        // unprocessed event has a version
                                        if let localVersion = localVersionInfo.version {
                                            // both have version
                                            let instanceIdMatch: Bool = unprocessedEventVersion.instanceId == localVersion.instanceId
                                            let lastSeenOlderThanRemote: Bool =
                                                unprocessedEventVersion.versionCounter >= localVersion.versionCounter

                                            let hasCommittedVersion: Bool = instanceIdMatch
                                                && localVersion.syncProtocolVersion == DataSynchronizer.syncProtocolVersion
                                                && !lastSeenOlderThanRemote

                                            if !hasCommittedVersion {
                                                action = .conflict
                                                message = .versionDifferentUnprocessedEvent
                                            }
                                        }
                                    }
                                }

                                // 2. Otherwise, the unprocessed event can be safely dropped and ignored in future R2L
                                //    passes. Continue on to checking the operation type.
                            }

                            if action == nil { // if we haven't hit an error or conflict yet
                                // iii. Check the operation type
                                switch localChangeEvent.operationType {
                                // 1. INSERT
                                case .insert:
                                    nextVersion = DocumentVersionInfo.freshVersionDocument()

                                    // It's possible that we may insert after a delete happened and we didn't get a
                                    // notification for it. There's nothing we can do about this.

                                    // a. Insert document into remote database
                                    do {
                                        _ = try remoteColl.insertOne(
                                            DataSynchronizer.withNewVersion(document: localChangeEvent.fullDocument!, newVersion: nextVersion!))
                                    } catch {
                                        // b. If an error happens:

                                        // i. That is not a duplicate key exception, report an error to the error
                                        // listener.
                                        if let err: StitchError = error as? StitchError {
                                            if case .serviceError(let msg, let code) = err,
                                               code == .mongoDBError, msg.contains("E11000") {
                                                action = .conflict
                                                message = .duplicateKeyException
                                            } else {
                                                action = .dropEventAndPause
                                                message = .exceptionOnInsert(exception: error.localizedDescription)
                                                suppressLocalEvent = true
                                                syncError = .mongoDBError(message.description, error)
                                            }
                                        } else {
                                            action = .dropEventAndPause
                                            message = .exceptionOnInsert(exception: error.localizedDescription)
                                            suppressLocalEvent = true
                                            syncError = .mongoDBError(message.description, error)
                                        }
                                    }
                                // 2. REPLACE
                                case .replace:
                                    if let localDoc = localDoc {
                                        nextVersion = localVersionInfo.nextVersion
                                        let nextDoc = DataSynchronizer.withNewVersion(document: localDoc, newVersion: nextVersion!)

                                        // a. Update the document in the remote database using a query for the _id and the
                                        //    version with an update containing the replacement document with the version
                                        //    counter incremented by 1.
                                        var resultOrNil: RemoteUpdateResult?
                                        do {
                                            resultOrNil = try remoteColl.updateOne(
                                                filter: localVersionInfo.filter!,
                                                update: nextDoc)
                                        } catch {
                                            action = .dropEventAndPause
                                            message = .exceptionOnReplace(exception: error.localizedDescription)
                                            suppressLocalEvent = true
                                            syncError = .mongoDBError(message.description, error)
                                            resultOrNil = nil
                                        }
                                        // c. If no documents are matched, record that a conflict has occurred.
                                        if let result = resultOrNil, result.matchedCount == 0 {
                                            action = .conflict
                                            message = .versionDifferentReplacedDoc
                                        }
                                    } else {
                                        action = .dropEventAndPause
                                        message = .expectedLocalDocumentToExist
                                        suppressLocalEvent = true
                                        syncError = .documentDoesNotExist(SyncMessage.expectedLocalDocumentToExist.description)
                                    }

                                // 3. UPDATE
                                case .update:
                                    if localDoc != nil {
                                        if let localUpdateDescription = localChangeEvent.updateDescription {
                                            if localUpdateDescription.removedFields.isEmpty
                                                && localUpdateDescription.updatedFields.isEmpty {
                                                // if the translated update is empty, then this update is a noop, and we
                                                // shouldn't update because it would improperly update the version
                                                // information.
                                                action = .dropEvent
                                                message = .emptyUpdateDescription
                                                suppressLocalEvent = true
                                            } else {
                                                // a. Update the document in the remote database using a query for the _id and the
                                                //    version with an update containing the replacement document with the version
                                                //    counter incremented by 1.

                                                // create an update document from the local change event's update description, and
                                                // set the version of the new document to the next logical version
                                                nextVersion = localVersionInfo.nextVersion

                                                let unset = localUpdateDescription.removedFields.reduce(into: Document(), { (result, key) in
                                                    result[key] = true
                                                })
                                                var sets = localUpdateDescription.updatedFields
                                                sets[documentVersionField] = nextVersion
                                                var translatedUpdate: Document = [
                                                    "$set": sets
                                                ]
                                                if unset.count > 0 {
                                                    translatedUpdate["$unset"] = unset
                                                }
                                                var resultOrNil: RemoteUpdateResult?
                                                do {
                                                    resultOrNil = try remoteColl.updateOne(
                                                        filter: localVersionInfo.filter!,
                                                        update: translatedUpdate
                                                    )
                                                } catch {
                                                    // b. If an error happens, report an error to the error listener.
                                                    action = .dropEventAndPause
                                                    message = .exceptionOnUpdate(exception: error.localizedDescription)
                                                    suppressLocalEvent = true
                                                    syncError = .mongoDBError(message.description, error)
                                                    resultOrNil = nil
                                                }
                                                if let result = resultOrNil, result.matchedCount == 0 {
                                                    // c. If no documents are matched, record that a conflict has occurred.
                                                    action = .conflict
                                                    message = .versionDifferentUpdatedDoc
                                                }
                                            }
                                        } else {
                                            action = .dropEvent
                                            message = .emptyUpdateDescription
                                            suppressLocalEvent = true
                                        }
                                    } else {
                                        action = .dropEventAndPause
                                        message = .expectedLocalDocumentToExist
                                        syncError = .documentDoesNotExist(SyncMessage.expectedLocalDocumentToExist.description)
                                    }
                                case .delete:
                                    nextVersion = nil
                                    let resultOrNil: RemoteDeleteResult?
                                    do {
                                        resultOrNil = try remoteColl.deleteOne(localVersionInfo.filter!)
                                    } catch {
                                        action = .dropEventAndPause
                                        message = .exceptionOnDelete(exception: error.localizedDescription)
                                        syncError = .mongoDBError(message.description, error)
                                        suppressLocalEvent = true
                                        resultOrNil = nil
                                    }
                                    // c. If no documents are matched, record that a conflict has occurred.
                                    if let result = resultOrNil, result.deletedCount == 0 {
                                        remoteDocument = try remoteColl.find(docFilter).first()
                                        remoteDocumentFetched = true
                                        if remoteDocument != nil {
                                            action = .conflict
                                            message = .versionDifferentDeletedDoc
                                        }
                                    }
                                    if action == nil { // if we haven't encountered an error/conflict already
                                        action = .deleteLocalAndDesync
                                        message = .documentDeleted
                                    }
                                default:
                                    action = .dropEventAndPause
                                    message = .unknownOptype(opType: localChangeEvent.operationType)
                                }
                            } else {
                                nextVersion = nil
                            }

                            let isConflicted: Bool

                            switch action ?? .wait {
                            case .conflict:
                                isConflicted = true
                            default:
                                isConflicted = false
                            }

                            logger.i(
                                "t='\(logicalT)': \(SyncMessage.l2rMethod) ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) conflict=\(isConflicted)")

                            if !isConflicted {
                                // iv. If no conflict has occurred, move on to the remote to local sync routine.
                                // since we strip version information from documents before setting pending writes, we
                                // don't have to worry about a stale document version in the event here.
                                let uncommittedEvent: ChangeEvent<Document>! = docConfig.uncommittedChangeEvent

                                if !suppressLocalEvent {
                                    let localEventToEmit = uncommittedEvent.withoutUncommittedWrites()
                                    localSyncWriteModelContainer.addLocalChangeEvent(localChangeEvent: localEventToEmit)
                                }

                                // do this later before change is committed since it requires a write lock which we
                                // cannot own while locking for read
                                setPendingWritesComplete = true
                                remoteChangeEvent = nil
                            } else {
                                // v. Otherwise, invoke the collection-level conflict handler with the local change
                                // event and the remote change event (synthesized by doing a lookup of the document or
                                // sourced from the listener)
                                if !remoteDocumentFetched {
                                    remoteChangeEvent =
                                        try synthesizedRemoteChangeEvent(in: remoteColl, with: docConfig.documentId.value)
                                } else {
                                    remoteChangeEvent =
                                        synthesizedRemoteChangeEvent(
                                            for: MongoNamespace.init(databaseName: remoteColl.databaseName, collectionName: remoteColl.name),
                                            with: docConfig.documentId.value,
                                            for: remoteDocument)
                                }
                            }
                        }
                    }

                    if setPendingWritesComplete, let uncommittedChangeEvent = docConfig.uncommittedChangeEvent {
                        if let uncommittedDocument = uncommittedChangeEvent.fullDocument {
                            docConfig.setPendingWritesComplete(atHash: HashUtils.hash(doc:
                                DataSynchronizer.sanitizeDocument(uncommittedDocument)), atVersion: nextVersion)

                            let opType: OperationType = uncommittedChangeEvent.operationType
                            if case .delete = opType {} else {
                                try localSyncWriteModelContainer.addConfigWrite(write:
                                    MongoCollection<Document>.ReplaceOneModel(docConfig: docConfig))
                            }
                        }
                    }

                    if let actionToEnqueue = action {
                        localSyncWriteModelContainer.merge(
                            try enqueueAction(nsConfig: nsConfig, docConfig: docConfig, remoteChangeEvent: remoteChangeEvent,
                                              action: actionToEnqueue, message: message, caller: SyncMessage.l2rMethod, error: syncError))
                    }
                }
                localSyncWriteModelContainer.commitAndClear()
            }
        }
        logger.i("t='\(logicalT)': \(SyncMessage.l2rMethod) END")

        // 3. If there are still local writes pending for the document, it will go through the L2R
        //    phase on a subsequent pass and try to commit changes again.
    }

    private func enqueueAction(nsConfig: NamespaceSynchronization, docConfig: CoreDocumentSynchronization,
                               remoteChangeEvent: ChangeEvent<Document>!, action: SyncAction, message: SyncMessage,
                               caller: String, error: DataSynchronizerError!) throws -> LocalSyncWriteModelContainer? {
        let syncMessage: String = SyncMessage.constructMessage(action: action, message: message,
                                                               context: (logicalT: logicalT, caller: caller, namespace: nsConfig.namespace, documentId: docConfig.documentId))

        logger.d(syncMessage)

        switch action {
        case .dropEvent, .wait:
            return nil
        case .applyAndVersionFromRemote:
            let remoteDocumentForApplyAndVersion: Document! = remoteChangeEvent.fullDocument

            let applyNewVersion: Document = DocumentVersionInfo.freshVersionDocument()
            let writeContainer: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

            writeContainer.merge(try replaceOrUpsertOneFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId,
                                             remoteDocument: remoteDocumentForApplyAndVersion, atVersion: applyNewVersion))
            writeContainer.addRemoteWrite(write: .updateOne(filter: [idField: docConfig.documentId.value] as Document,
                                                            update: DataSynchronizer.updateDocument(forVersion: applyNewVersion)))

            docConfig.setPendingWritesComplete(atHash: HashUtils.hash(doc: DataSynchronizer.sanitizeDocument(remoteDocumentForApplyAndVersion)),
                                               atVersion: applyNewVersion)
            writeContainer.addConfigWrite(write: try MongoCollection<Document>.ReplaceOneModel(docConfig: docConfig))

            return writeContainer
        case .applyFromRemote:
            let remoteDocumentForApply: Document! = remoteChangeEvent.fullDocument
            let remoteVersion: Document! = DocumentVersionInfo.getDocumentVersionDoc(document: remoteDocumentForApply)

            return try replaceOrUpsertOneFromRemote(nsConfig: nsConfig,
                                                    documentId: docConfig.documentId,
                                                    remoteDocument: remoteDocumentForApply,
                                                    atVersion: remoteVersion)
        case .conflict:
            return try resolveConflict(nsConfig: nsConfig, docConfig: docConfig, remoteEvent: remoteChangeEvent)
        case .remoteFind:
            return try remoteFind(nsConfig: nsConfig, docConfig: docConfig, caller: caller)
        case .dropEventAndDesync:
            return emitErrorAndDesync(nsConfig: nsConfig, docConfig: docConfig, error: error)
        case .dropEventAndPause:
            return emitErrorAndPause(docConfig: docConfig, error: error)
        case .deleteLocal:
            return deleteOneFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId)
        case .deleteLocalAndDesync:
            return desyncDocumentsFromRemote(nsConfig: nsConfig, documentIds: [docConfig.documentId])
                .withPostCommit { self.triggerListening(to: nsConfig.namespace) }
        }
    }

    func remoteFind(nsConfig: NamespaceSynchronization, docConfig: CoreDocumentSynchronization, caller: String) throws
        -> LocalSyncWriteModelContainer? {
        let lastSeenVersionInfo: DocumentVersionInfo? = try? DocumentVersionInfo.getLocalVersionInfo(docConfig: docConfig)

        var action: SyncAction
        var message: SyncMessage
        var remoteChangeEvent: ChangeEvent<Document>!

        let isPendingWrite: Bool = docConfig.uncommittedChangeEvent != nil

        // fetch the latest version to guard against stale events from other clients
        do {
            if let newestRemoteDocument: Document = try self.remoteCollection(for: nsConfig.namespace)
                .find([idField: docConfig.documentId.value]).first() {
                // we successfully found newest document

                if let newestRemoteVersionInfo: DocumentVersionInfo? =
                    try? DocumentVersionInfo.getRemoteVersionInfo(remoteDocument: newestRemoteDocument) {
                    // we successfully extracted document version info
                    var isStaleEvent: Bool = false
                    if let newestRemoteVersion = newestRemoteVersionInfo?.version {
                        if let lastSeenVersion = lastSeenVersionInfo?.version {
                            // both newest and last seen have versions
                            if lastSeenVersion.instanceId == newestRemoteVersion.instanceId {
                                isStaleEvent = true
                            }
                        }
                    }
                    if isStaleEvent {
                        action = .dropEvent
                        message = .staleEvent
                    } else {
                        action = isPendingWrite ? .conflict : .applyFromRemote
                        message = .remoteFindReplacedDoc
                        remoteChangeEvent = ChangeEvents.changeEventForLocalReplace(namespace: nsConfig.namespace,
                                                                                    documentId: docConfig.documentId.value,
                                                                                    document: newestRemoteDocument,
                                                                                    writePending: docConfig.hasUncommittedWrites)
                    }
                } else {
                    // could not extract version info
                    action = .dropEventAndDesync
                    message = .cannotParseRemoteVersion
                }
            } else {
                // remote fetch was empty
                if isPendingWrite {
                    action = .conflict
                    remoteChangeEvent = ChangeEvents.changeEventForLocalDelete(namespace: nsConfig.namespace,
                                                                               documentId: docConfig.documentId.value,
                                                                               writePending: docConfig.hasUncommittedWrites)
                } else {
                    action = .deleteLocalAndDesync
                }
                message = .remoteFindDeletedDoc
            }
        } catch {
            // error with remote fetch
            action = .conflict
            message = .remoteFindFailed
        }

        return try enqueueAction(nsConfig: nsConfig, docConfig: docConfig, remoteChangeEvent: remoteChangeEvent, action: action,
                                 message: message, caller: caller, error: nil)
    }

    private func newLocalSyncWriteModelContainer(nsConfig: NamespaceSynchronization) -> LocalSyncWriteModelContainer {
        return LocalSyncWriteModelContainer(nsConfig: nsConfig,
                                     localCollection: localCollection(for: nsConfig.namespace),
                                     remoteCollection: remoteCollection(for: nsConfig.namespace),
                                     undoCollection: undoCollection(for: nsConfig.namespace),
                                     eventDispatcher: self.eventDispatcher,
                                     dataSynchronizerLogTag: eventDispatchQueueLabel)
    }

    /**
     * Returns a synthesized change event for a remote document.
     *
     * @param remoteColl the collection the document lives in.
     * @param documentId the _id of the document.
     * @return a synthesized change event for a remote document.
     */
    private func synthesizedRemoteChangeEvent(
        in remoteColl: CoreRemoteMongoCollection<Document>,
        with documentId: BSONValue
        ) throws -> ChangeEvent<Document> {
        return synthesizedRemoteChangeEvent(
            for: MongoNamespace.init(databaseName: remoteColl.databaseName, collectionName: remoteColl.name),
            with: documentId,
            for: try remoteColl.find([idField: documentId]).first())
    }

    /**
     * Returns a synthesized change event for a remote document.
     *
     * @param ns         the namspace where the document lives.
     * @param documentId the _id of the document.
     * @param document   the remote document.
     * @return a synthesized change event for a remote document.
     */
    private func synthesizedRemoteChangeEvent(
        for namespace: MongoNamespace,
        with documentId: BSONValue,
        for document: Document?
        ) -> ChangeEvent<Document> {
        // a. When the document is looked up, if it cannot be found the synthesized change event is a
        // DELETE, otherwise it's a REPLACE.
        if let document = document {
            return ChangeEvents.changeEventForLocalReplace(namespace: namespace, documentId: documentId, document: document, writePending: false)

        } else {
            return ChangeEvents.changeEventForLocalDelete(namespace: namespace, documentId: documentId, writePending: false)
        }

    }

    /**
     * Resolves a conflict between a synchronized document's local and remote state. The resolution
     * will result in either the document being desynchronized or being replaced with some resolved
     * state based on the conflict resolver specified for the document.
     *
     * @param namespace   the namespace where the document lives.
     * @param docConfig   the configuration of the document that describes the resolver and current
     *                    state.
     * @param remoteEvent the remote change event that is conflicting.
     */
    private func resolveConflict(nsConfig: NamespaceSynchronization,
                                 docConfig: CoreDocumentSynchronization,
                                 remoteEvent: ChangeEvent<Document>) throws -> LocalSyncWriteModelContainer? {
        let documentId: AnyBSONValue = docConfig.documentId
        let namespace: MongoNamespace = nsConfig.namespace
        guard let localEvent = docConfig.uncommittedChangeEvent else {
            logger.f("t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId.value) missing uncommitted change "
                + "event on document configuration; cannot resolve conflict")
            return nil
        }

        guard let conflictHandler = nsConfig.conflictHandler else {
            logger.f("t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId.value) no conflict resolver set; "
                + "cannot resolve yet")
            return nil
        }

        logger.i(
            "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId.value) resolving conflict between "
                + "localOp=\(localEvent.operationType) remoteOp=\(remoteEvent.operationType)")

        // 2. Based on the result of the handler determine the next state of the document.
        var resolvedDocument: Document?
        do {
            // no need to transform the change events for the user, since the conflict handler data structure
            // will take care of that already.
            resolvedDocument = try DataSynchronizer.resolveConflictWithResolver(
                conflictResolver: conflictHandler,
                documentId: documentId.value,
                localEvent: localEvent,
                remoteEvent: remoteEvent)
        } catch {
            let errorPrefix = "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId.value) resolution "
                + "exception"
            return emitErrorAndPause(docConfig: docConfig, error: .resolutionError(errorPrefix, error))
        }

        let remoteVersion: Document?
        if remoteEvent.operationType == .delete {
            // We expect there will be no version on the document. Note: it's very possible
            // that the document could be reinserted at this point with no version field and we
            // would end up deleting it, unless we receive a notification in time.
            remoteVersion = nil
        } else {
            do {
                remoteVersion = try DocumentVersionInfo.getRemoteVersionInfo(remoteDocument: remoteEvent.fullDocument!)?.versionDoc
            } catch {
                let error: DataSynchronizerError = .decodingError(
                    "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) got a remote "
                        + "document that could not have its version info parsed "
                        + "; dropping the event, and desyncing the document")
                return emitErrorAndDesync(nsConfig: nsConfig, docConfig: docConfig, error: error)
                    .withPostCommit({self.triggerListening(to: namespace)})
            }
        }

        var sanitizedRemoteDocument: Document?
        if let remoteDocument = remoteEvent.fullDocument {
            sanitizedRemoteDocument = DataSynchronizer.sanitizeDocument(remoteDocument)
        }

        let acceptRemote = (sanitizedRemoteDocument == nil && resolvedDocument == nil)
            || (sanitizedRemoteDocument != nil
                && bsonEquals(sanitizedRemoteDocument, resolvedDocument))

        // a. If the resolved document is not nil:
        if let docForStorage = resolvedDocument {
            // Update the document locally which will keep the pending writes but with
            // a new version next time around.
            logger.i(
                "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId.value) replacing local with resolved document "
                    + "with remote version acknowledged: \(docForStorage)")
            if acceptRemote {
                // i. If the remote document is equal to the resolved document, replace the document
                //    locally, mark the document as having no pending writes, and emit a REPLACE change
                //    event if the document had not existed prior, or UPDATE if it had.
                return try self.replaceOrUpsertOneFromRemote(
                    nsConfig: nsConfig,
                    documentId: documentId,
                    remoteDocument: docForStorage,
                    atVersion: remoteVersion)
            } else {
                // ii. Otherwise, replace the local document with the resolved document locally, mark that
                //     there are pending writes for this document, and emit an UPDATE change event, or a
                //     DELETE change event (if the remoteEvent's operation type was DELETE).
                return try self.updateOrUpsertOneFromResolution(
                    nsConfig: nsConfig,
                    documentId: documentId,
                    document: docForStorage,
                    atVersion: remoteVersion,
                    remoteEvent: remoteEvent)
            }
            // b. If the resolved document is not null:
        } else {
            logger.i(
                "t='\(docConfig.documentId)': resolveConflict ns=\(namespace) documentId=\(documentId) deleting local and remote with remote "
                    + "version acknowledged")

            if acceptRemote {
                // i. If the remote event was a DELETE, delete the document locally, desynchronize the
                //    document, and emit a change event for the deletion.
                return self.deleteOneFromRemote(nsConfig: nsConfig, documentId: documentId)
            } else {
                // ii. Otherwise, delete the document locally, mark that there are pending writes for this
                //     document, and emit a change event for the deletion.
                return try self.deleteOneFromResolution(nsConfig: nsConfig, documentId: documentId, atVersion: remoteVersion)
            }
        }
    }

    /**
     * Returns the resolution of resolving the conflict between a local and remote event using
     * the given conflict resolver.
     *
     * @param conflictResolver the conflict resolver to use.
     * @param documentId       the document id related to the conflicted events.
     * @param localEvent       the conflicted local event.
     * @param remoteEvent      the conflicted remote event.
     * @return the resolution to the conflict.
     */
    private static func resolveConflictWithResolver(conflictResolver: AnyConflictHandler,
                                                    documentId: BSONValue,
                                                    localEvent: ChangeEvent<Document>,
                                                    remoteEvent: ChangeEvent<Document>) throws -> Document? {
        return try conflictResolver.resolveConflict(
            documentId: documentId,
            localEvent: localEvent,
            remoteEvent: remoteEvent)
    }

    /**
     * Requests that a document be no longer be synchronized by the given _id. Any uncommitted writes
     * will be lost.
     *
     * @param namespace  the namespace to put the document in.
     * @param documentId the _id of the document.
     */
    internal func desyncDocumentsFromRemote(nsConfig: NamespaceSynchronization,
                                            documentIds: [AnyBSONValue]) -> LocalSyncWriteModelContainer {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        nsConfig.nsLock.assertWriteLocked()

        let container: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

        // remove the synchronized document from the nsConfig and add to the container
        documentIds.forEach({
            nsConfig[$0.value] = nil
            container.addDocId(id: $0)}
        )

        // schedule documents for delete from the local collection
        container.addLocalWrite(write: MongoCollection<Document>.DeleteManyModel(
            [idField: ["$in": documentIds.map({$0.value})] as Document] as Document))
        container.addConfigWrite(write: MongoCollection<Document>.DeleteManyModel(
            docConfigFilter(forNamespace: nsConfig.namespace, withDocumentIds: documentIds)))

        return container
    }

    /**
     * Replaces a single synchronized document by its given id with the given full document
     * replacement. No replacement will occur if the _id is not being synchronized.
     *
     * @param nsConfig  the namespace configuration for the namespace where the document lives.
     * @param documentId the _id of the document.
     * @param remoteDocument   the replacement document.
     */
    private func replaceOrUpsertOneFromRemote(nsConfig: NamespaceSynchronization,
                                              documentId: AnyBSONValue,
                                              remoteDocument: Document,
                                              atVersion: Document?) throws -> LocalSyncWriteModelContainer? {
        let namespace = nsConfig.namespace

        nsConfig.nsLock.assertWriteLocked()
        guard let config = syncConfig[namespace]?[documentId.value] else {
            return nil
        }

        // Since we are accepting the remote document as the resolution to the conflict, it may
        // contain version information. Clone the document and remove forbidden fields from it before
        // storing it in the collection.
        let docForStorage = DataSynchronizer.sanitizeDocument(remoteDocument)
        config.setPendingWritesComplete(atHash: HashUtils.hash(doc: docForStorage), atVersion: atVersion)

        let container: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

        let event: ChangeEvent<Document> = ChangeEvents.changeEventForLocalReplace(
            namespace: namespace,
            documentId: documentId.value,
            document: docForStorage,
            updateDescription: nil,
            writePending: false)

        container.addDocId(id: documentId)
        container.addConfigWrite(write: try MongoCollection<Document>.ReplaceOneModel(docConfig: config))
        container.addLocalWrite(write: MongoCollection<Document>.ReplaceOneModel(
            filter: [idField: documentId.value], replacement: docForStorage, upsert: true))
        container.addLocalChangeEvent(localChangeEvent: event)

        return container
    }

    /**
     * Replaces a single synchronized document by its given id with the given full document
     * replacement. No replacement will occur if the _id is not being synchronized.
     *
     * @param namespace  the namespace where the document lives.
     * @param documentId the _id of the document.
     * @param document   the replacement document.
     */
    private func updateOrUpsertOneFromResolution(nsConfig: NamespaceSynchronization,
                                                 documentId: AnyBSONValue,
                                                 document: Document,
                                                 atVersion: Document?,
                                                 remoteEvent: ChangeEvent<Document>) throws -> LocalSyncWriteModelContainer? {
        let namespace = nsConfig.namespace

        nsConfig.nsLock.assertWriteLocked()
        guard let config = syncConfig[namespace]?[documentId.value] else {
            return nil
        }

        // Remove forbidden fields from the resolved document before it will updated/upserted in the
        // local collection.
        var docForStorage = DataSynchronizer.sanitizeDocument(document)

        if !docForStorage.keys.contains(idField), remoteEvent.documentKey.keys.contains(idField) {
            docForStorage[idField] = remoteEvent.documentKey[idField]
        }

        let event: ChangeEvent<Document>
        if case .delete = remoteEvent.operationType {
            event = ChangeEvents.changeEventForLocalInsert(namespace: namespace,
                                                           document: docForStorage,
                                                           documentId: documentId.value,
                                                           writePending: true)
        } else {
            guard let unsanitizedRemoteDocument = remoteEvent.fullDocument else {
                return nil // XXX should raise an error here?
            }

            let remoteDocument = DataSynchronizer.sanitizeDocument(unsanitizedRemoteDocument)
            event = ChangeEvents.changeEventForLocalUpdate(
                namespace: namespace,
                documentId: documentId.value,
                update: remoteDocument.diff(otherDocument: docForStorage),
                fullDocumentAfterUpdate: docForStorage,
                writePending: true)
        }
        config.setSomePendingWrites(
            atTime: logicalT,
            atVersion: atVersion,
            atHash: HashUtils.hash(doc: docForStorage),
            changeEvent: event)

        let container: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

        container.addDocId(id: documentId)
        container.addLocalWrite(write: MongoCollection<Document>.ReplaceOneModel(
            filter: [idField: documentId.value] as Document,
            replacement: docForStorage, upsert: true))
        container.addConfigWrite(write: try MongoCollection<Document>.ReplaceOneModel(docConfig: config))
        container.addLocalChangeEvent(localChangeEvent: event)

        return container
    }

    /**
     * Deletes a single synchronized document by its given id. No deletion will occur if the _id is
     * not being synchronized.
     *
     * @param namespace  the namespace where the document lives.
     * @param documentId the _id of the document.
     */
    private func deleteOneFromRemote(nsConfig: NamespaceSynchronization, documentId: AnyBSONValue) -> LocalSyncWriteModelContainer? {
        let namespace = nsConfig.namespace

        nsConfig.nsLock.assertWriteLocked()

        guard syncConfig[namespace]?[documentId.value] != nil else {
            return nil
        }

        let container: LocalSyncWriteModelContainer =
            desyncDocumentsFromRemote(nsConfig: nsConfig, documentIds: [documentId]).withPostCommit {
                self.triggerListening(to: namespace)
            }

        container.addLocalChangeEvent(localChangeEvent: ChangeEvents.changeEventForLocalDelete(
            namespace: namespace,
            documentId: documentId.value,
            writePending: false))

        return container
    }

    private func deleteOneFromResolution(nsConfig: NamespaceSynchronization,
                                         documentId: AnyBSONValue,
                                         atVersion: Document?) throws -> LocalSyncWriteModelContainer? {
        let namespace = nsConfig.namespace

        nsConfig.nsLock.assertWriteLocked()

        guard let config = syncConfig[namespace]?[documentId.value] else {
            return nil
        }

        let container: LocalSyncWriteModelContainer = newLocalSyncWriteModelContainer(nsConfig: nsConfig)

        let event = ChangeEvents.changeEventForLocalDelete(namespace: namespace, documentId: documentId.value, writePending: true)
        config.setSomePendingWrites(atTime: logicalT, atVersion: atVersion, atHash: 0, changeEvent: event)

        container.addDocId(id: documentId)
        container.addLocalWrite(write: MongoCollection<Document>.DeleteOneModel([idField: documentId.value]))
        container.addConfigWrite(write: try MongoCollection<Document>.ReplaceOneModel(docConfig: config))
        container.addLocalChangeEvent(localChangeEvent: event)

        return container
    }

    /**
     Starts data synchronization in a background thread.
     */
    public func start() {
        syncLock.write {
            if !self.isConfigured {
                return
            }

            instanceChangeStreamDelegate.start()

            if isSyncThreadEnabled {
                self.syncWorkItem = DispatchWorkItem { [weak self] in
                    repeat {
                        guard let dataSync = self else {
                            return
                        }

                        var successful = false
                        do {
                            successful = try dataSync.doSyncPass()
                        } catch {
                            self?.on(error: error, forDocumentId: nil, in: nil)
                        }
                        if successful {
                            sleep(DataSynchronizer.shortSleepSeconds)
                        } else {
                            sleep(DataSynchronizer.longSleepSeconds)
                        }
                    } while self?.syncWorkItem?.isCancelled == false
                }

                syncDispatchQueue.async(execute: self.syncWorkItem!)
            }
        }
    }

    /**
     Stops the background data synchronization thread.
     */
    public func stop() {
        // can't actually stop the data synchronization thread until it is started
        self.waitUntilInitialized()

        syncLock.write {
            instanceChangeStreamDelegate.stop()
        }

        guard let syncWorkItem = syncWorkItem else {
            return
        }
        syncWorkItem.cancel()
        let join = DispatchSemaphore.init(value: 0)
        syncWorkItem.notify(queue: syncDispatchQueue) {
            join.signal()
        }
        join.wait()
        self.syncWorkItem = nil
    }

    /**
     Requests that the given document _ids be synchronized.
     - parameter ids: the document _ids to synchronize.
     - parameter namespace: the namespace these documents belong to
     */
    func sync(ids: [BSONValue], in namespace: MongoNamespace) throws {
        self.waitUntilInitialized()

        operationsGroup.enter()
        defer { operationsGroup.leave() }

        try ids.forEach { id in
            guard let nsConfig = syncConfig[namespace] else {
                return
            }

            try nsConfig.nsLock.write {
                _ = try nsConfig.sync(id: id)
            }
        }

        // wrap in a synclock since triggerListening expects to be syncLocked
        syncLock.write {
            self.triggerListening(to: namespace)
        }
    }

    /**
     Stops synchronizing the given document _ids. Any uncommitted writes will be lost.

     - parameter ids: the _ids of the documents to desynchronize.
     */
    func desync(ids: [BSONValue], in namespace: MongoNamespace) throws {
        self.waitUntilInitialized()

        operationsGroup.enter()
        defer { operationsGroup.leave() }

        guard let nsConfig = syncConfig[namespace] else {
            return
        }

        syncLock.write {
            nsConfig.nsLock.write {
                let container: LocalSyncWriteModelContainer? =
                    desyncDocumentsFromRemote(nsConfig: nsConfig, documentIds: ids.map({AnyBSONValue($0)}))
                container?.commitAndClear()
            }
            self.triggerListening(to: namespace)
        }
    }

    /**
     Returns the set of synchronized document ids in a namespace.

     - returns: the set of synchronized document ids in a namespace.
     */
    func syncedIds(in namespace: MongoNamespace) -> Set<AnyBSONValue> {
        self.waitUntilInitialized()

        guard let nsConfig = syncConfig[namespace] else {
            return Set()
        }

        return Set(nsConfig.map({$0.documentId}))
    }

    /**
     Return the set of synchronized document _ids in a namespace
     that have been paused due to an irrecoverable error.

     - returns: the set of paused document _ids in a namespace
     */
    func pausedIds(in namespace: MongoNamespace) -> Set<AnyBSONValue> {
        self.waitUntilInitialized()

        guard let nsConfig = syncConfig[namespace] else {
            return Set()
        }

        return Set(nsConfig.compactMap { docConfig in
            guard docConfig.isPaused else {
                return nil
            }
            return docConfig.documentId
        })
    }

    /**
     A document that is paused no longer has remote updates applied to it.
     Any local updates to this document cause it to be resumed. An example of pausing a document
     is when a conflict is being resolved for that document and the handler throws an exception.

     - parameter documentId: the id of the document to resume syncing
     - returns: true if successfully resumed, false if the document
     could not be found or there was an error resuming
     */
    func resumeSync(for documentId: BSONValue,
                    in namespace: MongoNamespace) -> Bool {
        self.waitUntilInitialized()

        guard let nsConfig = syncConfig[namespace],
            let docConfig = nsConfig.nsLock.read({ return nsConfig[documentId] }) else {
                return false
        }

        docConfig.isPaused = false
        return !docConfig.isPaused
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote.

     - parameter namespace: the namespace to conduct this op
     - returns: the number of documents in the collection
     */
    func count(in namespace: MongoNamespace) throws -> Int {
        return try self.count(filter: Document(),
                              options: nil,
                              in: namespace)
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote
     according to the given options.

     - parameter filter:  the query filter
     - parameter options: the options describing the count
     - parameter namespace: the namespace to conduct this op
     - returns: the number of documents in the collection
     */
    func count(filter: Document,
               options: SyncCountOptions?,
               in namespace: MongoNamespace) throws -> Int {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let lock = self.syncConfig[namespace]?.nsLock else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }
        return try lock.read {
            return try localCollection(for: namespace, withType: Document.self)
                .count(filter, options: options?.toCountOptions)
        }
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - parameter namespace: the namespace to conduct this op
     - returns: the find iterable interface
     */
    func find<DocumentT: Codable>(in namespace: MongoNamespace) throws -> MongoCursor<DocumentT> {
        return try self.find(filter: Document.init(), options: nil, in: namespace)
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - parameter filter: the query filter for this find op
     - parameter options: the options for this find op
     - parameter namespace: the namespace to conduct this op
     - returns: the find iterable interface
     */
    func find<DocumentT: Codable>(filter: Document,
                                  options: SyncFindOptions?,
                                  in namespace: MongoNamespace) throws -> MongoCursor<DocumentT> {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let lock = self.syncConfig[namespace]?.nsLock else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }
        return try lock.read {
            return try localCollection(for: namespace).find(filter, options: options?.toFindOptions)
        }
    }

    /**
     Finds one document in the collection that has been synchronized with the remote.
     
     - parameter filter: the query filter for this find op
     - parameter options: the options for this find op
     - parameter namespace: the namespace to conduct this op
     - returns:  The resulting `Document` or nil if no such document exists
     */
    func findOne<DocumentT: Codable>(filter: Document,
                                     options: SyncFindOptions?,
                                     in namespace: MongoNamespace) throws -> DocumentT? {
        guard let lock = self.syncConfig[namespace]?.nsLock else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }
        return try lock.read {
            return try localCollection(for: namespace).findOne(filter, options: options?.toFindOptions)
        }
    }

    /**
     Aggregates documents that have been synchronized with the remote
     according to the specified aggregation pipeline.

     - parameter pipeline: the aggregation pipeline
     - parameter options: the options for this aggregate op
     - parameter namespace: the namespace to conduct this op
     - returns: an iterable containing the result of the aggregation operation
     */
    func aggregate(pipeline: [Document],
                   options: AggregateOptions? = nil,
                   in namespace: MongoNamespace) throws -> MongoCursor<Document> {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let lock = self.syncConfig[namespace]?.nsLock else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }
        return try lock.read {
            return try localCollection(for: namespace, withType: Document.self).aggregate(
                pipeline,
                options: options)
        }
    }

    /**
     Inserts the provided document. If the document is missing an identifier, the client should
     generate one. Syncs the newly inserted document against the remote.

     - parameter document: the document to insert
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the insert one operation
     */
    func insertOne(document: Document,
                   in namespace: MongoNamespace) throws -> SyncInsertOneResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }

        guard let (event, result): (ChangeEvent<Document>, InsertOneResult) = try nsConfig.nsLock.write({
            // Remove forbidden fields from the document before inserting it into the local collection.
            var docForStorage = DataSynchronizer.sanitizeDocument(document)
            guard let result = try localCollection(for: namespace).insertOne(&docForStorage) else {
                return nil
            }

            let config = try nsConfig.sync(id: result.insertedId)
            let event = ChangeEvents.changeEventForLocalInsert(
                namespace: namespace,
                document: docForStorage,
                documentId: result.insertedId,
                writePending: true)
            try config.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)
            return (event, result)
        }) else {
            return nil
        }

        syncLock.write {
            self.triggerListening(to: namespace)
        }

        self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event)
        return result.toSyncInsertOneResult
    }

    /**
     Inserts one or more documents. Syncs the newly inserted documents against the remote.

     - parameter documents: the documents to insert
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the insert many operation
     */
    func insertMany(documents: [Document], in namespace: MongoNamespace) throws -> SyncInsertManyResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }

        let lock = nsConfig.nsLock
        let (eventEmitters, result): ([() -> Void], InsertManyResult?) = try lock.write {

            // Remove forbidden fields from the documents before inserting them into the local collection.
            var docsForStorage = documents.map { DataSynchronizer.sanitizeDocument($0) }
            guard let result = try localCollection(for: namespace).insertMany(&docsForStorage) else {
                return ([], nil)
            }

            let eventEmitters = try result.insertedIds.compactMap({ (kv) -> (() -> Void)? in
                guard !(kv.value is BSONNull) else {
                    return nil
                }
                let documentId = kv.value
                let document = docsForStorage[kv.key]
                let event = ChangeEvents.changeEventForLocalInsert(namespace: namespace,
                                                                            document: document,
                                                                            documentId: documentId,
                                                                            writePending: true)
                let config = try nsConfig.sync(id: documentId)
                try config.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)
                return { self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event) }
            })

            return (eventEmitters, result)
        }

        if result != nil {
            syncLock.write {
                self.triggerListening(to: namespace)
            }
        }

        eventEmitters.forEach({$0()})
        return result?.toSyncInsertManyResult
    }

    /**
     Removes at most one document from the collection that has been synchronized with the remote
     that matches the given filter.  If no documents match, the collection is not
     modified.

     - parameter filter: the query filter to apply the the delete operation
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the remove one operation
     */
    func deleteOne(filter: Document,
                   options: DeleteOptions?,
                   in namespace: MongoNamespace) throws -> SyncDeleteResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard var nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: StitchClientErrorCode.couldNotLoadSyncInfo)
        }

        var desyncBlock: (() throws -> Void)?
        var emitEvent: (() -> Void)?
        defer {
            emitEvent?()
            do {
                try desyncBlock?()
            } catch {
                errorListener?.on(error: .fatalError(error), forDocumentId: nil)
            }
        }

        let lock = nsConfig.nsLock
        return try lock.write {

            let localColl = localCollection(for: namespace, withType: Document.self)

            guard var docToDelete = try localColl.find(filter).first(where: { _ in true}) else {
                return SyncDeleteResult(deletedCount: 0)
            }

            guard let documentId = docToDelete[idField],
                let docConfig = nsConfig[documentId] else {
                    return SyncDeleteResult(deletedCount: 0)
            }

            let undoColl = undoCollection(for: namespace)
            try undoColl.insertOne(&docToDelete)

            let result = try localColl.deleteOne(filter)
            let event =  ChangeEvents.changeEventForLocalDelete(
                namespace: namespace,
                documentId: documentId,
                writePending: true
            )

            // this block is to trigger coalescence for a delete after insert
            if let uncommittedEvent = docConfig.uncommittedChangeEvent,
                uncommittedEvent.operationType == OperationType.insert {

                desyncBlock = {
                    try self.desync(ids: [docConfig.documentId.value], in: docConfig.namespace)
                    try undoColl.deleteOne([idField: docConfig.documentId.value])
                }
                return result?.toSyncDeleteResult
            }

            try docConfig.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)

            try undoColl.deleteOne([idField: docConfig.documentId.value])

            emitEvent = { self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event) }

            return result?.toSyncDeleteResult
        }
    }

    /**
     Removes all documents from the collection that have been synchronized with the remote
     that match the given query filter.  If no documents match, the collection is not modified.

     - parameter filter: the query filter to apply the the delete operation
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the remove many operation
     */
    func deleteMany(filter: Document,
                    options: DeleteOptions?,
                    in namespace: MongoNamespace) throws -> SyncDeleteResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard var nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: StitchClientErrorCode.couldNotLoadSyncInfo)
        }

        var deferredBlocks = [(() throws -> Void)]()
        defer {
            deferredBlocks.forEach({
                do {
                    try $0()
                } catch {
                    errorListener?.on(error: .fatalError(error), forDocumentId: nil)
                }
            })
        }

        return try nsConfig.nsLock.write {
            let localColl = localCollection(for: namespace, withType: Document.self)
            let undoColl = undoCollection(for: namespace)

            let idsToDelete = try localColl.find(filter).compactMap { doc -> BSONValue? in
                var doc = doc
                try undoColl.insertOne(&doc)
                return doc[idField]
            }

            let result = try localColl.deleteMany(filter, options: options)

            try idsToDelete.forEach { documentId in
                guard let docConfig = nsConfig[documentId] else {
                    return
                }

                let event = ChangeEvents.changeEventForLocalDelete(
                    namespace: namespace,
                    documentId: documentId,
                    writePending: true
                )

                // this block is to trigger coalescence for a delete after insert
                if let uncommittedEvent = docConfig.uncommittedChangeEvent,
                    uncommittedEvent.operationType == OperationType.insert {

                    deferredBlocks.append {
                        try self.desync(ids: [docConfig.documentId.value],
                                        in: docConfig.namespace)
                        try undoColl.deleteOne([idField: documentId])
                    }
                    return
                }

                try docConfig.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)
                try undoColl.deleteOne([idField: documentId])
                deferredBlocks.append { self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event) }
            }

            return result?.toSyncDeleteResult
        }
    }

    /**
     Update a single document in the collection that have been synchronized with the remote
     according to the specified arguments. If the update results in an upsert,
     the newly upserted document will automatically become synchronized.
     - parameter filter: a document describing the query filter, which may not be null.
     - parameter update: a document describing the update, which may not be null. The update to
     apply must include only update operators.
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the update one operation
     */
    func updateOne(filter: Document,
                   update: Document,
                   options: SyncUpdateOptions?,
                   in namespace: MongoNamespace) throws -> SyncUpdateResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: StitchClientErrorCode.couldNotLoadSyncInfo)
        }

        var triggerNamespace = false
        var emitEvent: (() -> Void)?
        defer { emitEvent?() }
        let updateResult: SyncUpdateResult? = try nsConfig.nsLock.write {
            // read the local collection
            let localCollection = self.localCollection(for: namespace, withType: Document.self)
            let undoColl = self.undoCollection(for: namespace)

            let upsert = options?.upsert ?? false

            // fetch the document prior to updating
            let documentBeforeUpdate = try localCollection.find(filter).next()

            // if there was no document prior and this is not an upsert,
            // do not acknowledge the update
            if !upsert && documentBeforeUpdate == nil {
                return nil
            }

            if var backupDoc = documentBeforeUpdate {
                try undoColl.insertOne(&backupDoc)
            }

            // find and update the single document, returning the document post-update
            // if the document was deleted between our earlier check and now, it will not have
            // been updated. do not acknowledge the update
            guard let unsanitizedDocumentAfterUpdate = try localCollection.findOneAndUpdate(
                filter: filter,
                update: update,
                options: FindOneAndUpdateOptions.init(returnDocument: .after,
                                                      upsert: options?.upsert)),
                let documentId = unsanitizedDocumentAfterUpdate[idField] else {

                    if let documentIdBeforeUpdate = documentBeforeUpdate?[idField] {
                        try undoColl.deleteOne([idField: documentIdBeforeUpdate])
                    }

                    return nil
            }

            // Ensure that the update didn't add any forbidden fields to the document, and remove them if
            // it did.
            let documentAfterUpdate =
                try DataSynchronizer.sanitizeCachedDocument(unsanitizedDocumentAfterUpdate,
                                                            documentId: documentId,
                                                            in: localCollection)

            // if there was no document prior and this was an upsert,
            // treat this as an insert.
            // else this is an update
            triggerNamespace = documentBeforeUpdate == nil && upsert
            var config: CoreDocumentSynchronization
            let event: ChangeEvent<Document>
            if triggerNamespace {
                config = try nsConfig.sync(id: documentId)
                event = ChangeEvents.changeEventForLocalInsert(
                    namespace: namespace,
                    document: documentAfterUpdate,
                    documentId: documentId,
                    writePending: true)
            } else {
                // if the document config has been removed from the namespace
                // during the time this occured, a delete must have occured,
                // so we can swallow this update
                guard let docConfig = nsConfig[documentId],
                    let documentBeforeUpdate = documentBeforeUpdate,
                    let documentId = documentAfterUpdate[idField] else {
                        return nil
                }
                config = docConfig
                event = ChangeEvents.changeEventForLocalUpdate(
                    namespace: namespace,
                    documentId: documentId,
                    update: documentBeforeUpdate.diff(otherDocument: documentAfterUpdate),
                    fullDocumentAfterUpdate: documentAfterUpdate,
                    writePending: true)
            }

            try config.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)

            if let documentIdBeforeUpdate = documentBeforeUpdate?[idField] {
                try undoColl.deleteOne([idField: documentIdBeforeUpdate])
            }

            emitEvent = { self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event) }

            return SyncUpdateResult(matchedCount: 1,
                                    modifiedCount: 1,
                                    upsertedId: upsert ? documentId : nil)
        }

        if triggerNamespace {
            syncLock.write {
                self.triggerListening(to: namespace)
            }
        }

        return updateResult
    }

    /**
     Update all documents in the collection that have been synchronized with the remote
     according to the specified arguments. If the update results in an upsert,
     the newly upserted document will automatically become synchronized.
     - parameter filter: a document describing the query filter, which may not be null.
     - parameter update: a document describing the update, which may not be null. The update to
     apply must include only update operators.
     - parameter updateOptions: the options to apply to the update operation
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the update many operation
     */
    func updateMany(filter: Document,
                    update: Document,
                    options: SyncUpdateOptions?,
                    in namespace: MongoNamespace) throws -> SyncUpdateResult? {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        guard let nsConfig: NamespaceSynchronization = self.syncConfig[namespace] else {
            throw StitchError.clientError(
                withClientErrorCode: .couldNotLoadSyncInfo)
        }

        var deferredBlocks = [(() throws -> Void)]()
        defer {
            deferredBlocks.forEach({
                do {
                    try $0()
                } catch {
                    errorListener?.on(error: .fatalError(error), forDocumentId: nil)
                }
            })
        }
        let result: UpdateResult? = try nsConfig.nsLock.write {
            let localCollection = self.localCollection(for: namespace, withType: Document.self)
            let undoColl = self.undoCollection(for: namespace)

            // fetch all of the documents that this filter will match
            let beforeDocuments = try localCollection.find(filter)
            var idsToBeforeDocumentMap = [AnyBSONValue: Document]()

            // use the matched ids from prior to create a new filter.
            // this will prevent any race conditions if documents were
            // inserted between the prior find
            let ids = try beforeDocuments.compactMap({ (beforeDoc: Document) -> BSONValue? in
                guard let documentId = beforeDoc[idField] else {
                    // this should never happen, but let's ignore the document if it does
                    return nil
                }

                var beforeDoc = beforeDoc
                try undoColl.insertOne(&beforeDoc)
                idsToBeforeDocumentMap[AnyBSONValue(documentId)] = beforeDoc
                return beforeDoc[idField]
            })
            var updatedFilter = (options?.upsert ?? false) ? filter :
                [idField: ["$in": ids] as Document] as Document

            // do the bulk write
            let result = try localCollection.updateMany(filter: updatedFilter,
                                                        update: update,
                                                        options: options?.toUpdateOptions)

            // if this was an upsert, create the post-update filter using
            // the upserted id.
            if let upsertedId = result?.upsertedId {
                updatedFilter = [idField: upsertedId.value]
            }

            let upsert = options?.upsert ?? false
            // iterate over the after-update docs using the updated filter
            try localCollection.find(updatedFilter).forEach { unsanitizedAfterDocument in
                // get the id of the after-update document, and fetch the before-update
                // document from the map we created from our pre-update `find`
                guard let documentId = unsanitizedAfterDocument[idField] else {
                    return
                }

                let beforeDocument = idsToBeforeDocumentMap[AnyBSONValue(documentId)]

                // if there was no before-update document and this was not an upsert,
                // a document that meets the filter criteria must have been
                // inserted or upserted asynchronously between this find and the update.
                if beforeDocument == nil && !upsert {
                    return
                }

                // Ensure that the update didn't add any forbidden fields to the document, and remove
                // them if it did.
                let afterDocument =
                    try DataSynchronizer.sanitizeCachedDocument(unsanitizedAfterDocument,
                                                                documentId: documentId,
                                                                in: localCollection)

                // because we are looking up a bulk write, we may have queried documents
                // that match the updated state, but were not actually modified.
                // if the document before the update is the same as the updated doc,
                // assume it was not modified and take no further action
                if afterDocument == beforeDocument {
                    try undoColl.deleteOne([idField: documentId])
                    return
                }

                var config: CoreDocumentSynchronization
                let event: ChangeEvent<Document>

                // if there was no earlier document and this was an upsert,
                // treat the upsert as an insert, as far as sync is concerned
                // else treat it as a standard update
                if let beforeDocument = beforeDocument {
                    guard let docConfig = nsConfig[documentId] else {
                        return
                    }
                    config = docConfig
                    event = ChangeEvents.changeEventForLocalUpdate(
                        namespace: namespace,
                        documentId: documentId,
                        update: beforeDocument.diff(otherDocument: afterDocument),
                        fullDocumentAfterUpdate: afterDocument,
                        writePending: true)
                } else {
                    config = try nsConfig.sync(id: documentId)
                    event = ChangeEvents.changeEventForLocalInsert(
                        namespace: namespace,
                        document: afterDocument,
                        documentId: documentId,
                        writePending: true)
                }

                deferredBlocks.append { self.eventDispatcher.emitEvent(nsConfig: nsConfig, event: event) }
                try config.setSomePendingWritesAndSave(atTime: logicalT, changeEvent: event)
                try undoColl.deleteOne([idField: documentId])
            }

            return result
        }

        if result?.upsertedId != nil {
            syncLock.write {
                self.triggerListening(to: namespace)
            }
        }

        return result?.toSyncUpdateResult
    }

    /// Potentially pass along useful error information to the user.
    /// This should only be used for low level errors.
    func on(error: Error, forDocumentId documentId: BSONValue?, in namespace: MongoNamespace?) {
        guard let errorListener = self.errorListener else {
            return
        }

        guard let unwrappedNamespace = namespace, let unwrappedDocumentId = documentId else {
            logger.e(error.localizedDescription)
            logger.e("Fatal error occured: \(error.localizedDescription)")
            self.eventDispatchQueue.async {
                errorListener.on(error: .fatalError(error), forDocumentId: documentId)
            }
            return
        }

        guard let config = syncConfig[unwrappedNamespace]?[unwrappedDocumentId] else {
            logger.e(error.localizedDescription)
            logger.e("Fatal error occured in namespace \(unwrappedNamespace) " +
                "for documentId \(unwrappedDocumentId): \(error.localizedDescription)")
            self.eventDispatchQueue.async {
                errorListener.on(error: .fatalError(error), forDocumentId: documentId)
            }
            return
        }

        emitError(docConfig: config, error: .fatalError(error))
    }

    private func emitErrorAndPause(docConfig: CoreDocumentSynchronization,
                                   error errorOrNil: DataSynchronizerError?) -> LocalSyncWriteModelContainer? {
        var errorToEmit: DataSynchronizerError
        if let error = errorOrNil {
            errorToEmit = error
        } else {
            errorToEmit = .unknownError("unable to unwrap error")
        }
        emitError(docConfig: docConfig, error: errorToEmit)
        pauseDocument(docConfig: docConfig)
        return nil
    }

    private func emitErrorAndDesync(nsConfig: NamespaceSynchronization,
                                    docConfig: CoreDocumentSynchronization,
                                    error errorOrNil: DataSynchronizerError?) -> LocalSyncWriteModelContainer {
        var errorToEmit: DataSynchronizerError
        if let error = errorOrNil {
            errorToEmit = error
        } else {
            errorToEmit = .unknownError("unable to unwrap error")
        }
        emitError(docConfig: docConfig, error: errorToEmit)
        return desyncDocumentsFromRemote(nsConfig: nsConfig, documentIds: [docConfig.documentId])
    }

    /**
     Pauses synchronization for a given document id.
     - parameter docConfig: document configuration to pause
    */
    private func pauseDocument(docConfig: CoreDocumentSynchronization) {
        logger.e("Pausing document \(docConfig.documentId.value)")
        docConfig.isPaused = true
    }

    /**
     Emits an error for the given document id. This should be used
     for irrecoverable errors. Pauses the doc config.
     - parameter docConfig: document configuration the error occured on
     - parameter error: the error that occured
     */
    private func emitError(docConfig: CoreDocumentSynchronization,
                           error: DataSynchronizerError) {
        let documentId = docConfig.documentId.value
        logger.e(error.localizedDescription)

        guard let errorListener = self.errorListener else {
            return
        }

        self.eventDispatchQueue.async {
            errorListener.on(error: error, forDocumentId: documentId)
        }
    }

    /**
     Trigger change stream listeners for a given namespace
     - parameter namespace: namespace to listen to
     */
    private func triggerListening(to namespace: MongoNamespace) {
        syncLock.assertWriteLocked()
        guard let nsConfig = self.syncConfig[namespace] else {
            return
        }

        guard nsConfig.count > 0,
            nsConfig.isConfigured else {
            self.instanceChangeStreamDelegate.remove(namespace: namespace)
            return
        }

        self.instanceChangeStreamDelegate.append(namespace: namespace)
        self.instanceChangeStreamDelegate.stop(namespace: namespace)
        self.instanceChangeStreamDelegate.start(namespace: namespace)
    }

    private func latestStaleDocumentsFromRemote(nsConfig: NamespaceSynchronization,
                                                staleIds: Set<AnyBSONValue>) throws -> [Document] {
        let ids = staleIds.map { $0.value }
        guard ids.count > 0 else { return [] }
        return try self.remoteCollection(for: nsConfig.namespace)
            .find([idField: ["$in": ids] as Document]).toArray()
    }

    public var allStreamsAreOpen: Bool {
        return syncLock.write {
            return self.instanceChangeStreamDelegate.allStreamsAreOpen
        }
    }

    /**
     * Blocks until the initialization of the DataSynchronizer is complete. This can be triggered by the initial
     * initialization, or a reinitialization.
     */
    internal func waitUntilInitialized() {
        if let initWorkItem = self.initWorkItem {
            initWorkItem.wait()
            self.initWorkItem = nil
        }
    }

    // MARK: Utilities

    /**
     Given a BSON document, remove any forbidden fields and return the document. If no changes are
     made, the original document reference is returned. If changes are made, a cloned copy of the
     document with the changes will be returned.

     - parameter document: the document from which to remove forbidden fields
     - returns: a BsonDocument without any forbidden fields.
     */
    internal static func sanitizeDocument(_ document: Document) -> Document {
        guard document.hasKey(documentVersionField) else {
            return document
        }

        return document.filter { $0.key != documentVersionField }
    }

    /**
     Given a local collection, a document fetched from that collection, and its _id, ensure that
     the document does not contain forbidden fields (currently just the document version field),
     and remove them from the document and the local collection. If no changes are made, the
     original document reference is returned. If changes are made, a cloned copy of the document
     with the changes will be returned.

     - parameter localCollection: the local MongoCollection from which the document was fetched
     - parameter document: the document fetched from the local collection. this argument may be mutated
     - parameter documentId: the _id of the fetched document (taken as an arg so that if the caller
     already knows the _id, the document need not be traversed to find it)
     - returns: a BsonDocument without any forbidden fields.
     */
    private static func sanitizeCachedDocument(
        _ document: Document,
        documentId: BSONValue,
        in localCollection: ThreadSafeMongoCollection<Document>
    ) throws -> Document {
        guard document[documentVersionField] != nil else {
            return document
        }

        let clonedDoc = sanitizeDocument(document)

        try localCollection.findOneAndUpdate(filter: [idField: documentId],
                                             update: ["$unset": [documentVersionField: 1] as Document])
        return clonedDoc
    }

    /**
     * Returns the remote collection representing the given namespace.
     *
     * @param namespace   the namespace referring to the remote collection.
     * @param resultClass the {@link Class} that represents documents in the collection.
     * @param <T>         the type documents in the collection.
     * @return the remote collection representing the given namespace.
     */
    private func remoteCollection<T: Codable>(for namespace: MongoNamespace,
                                              withType type: T.Type = T.self) -> CoreRemoteMongoCollection<T> {
        return remoteClient
            .db(namespace.databaseName)
            .collection(namespace.collectionName, withCollectionType: T.self)
    }

    /**
     Returns the local collection representing the given namespace.

     - parameter namespace: the namespace referring to the local collection.
     - parameter type: the type of document in this collection
     - returns: the local collection representing the given namespace.
     */
    private func localCollection(for namespace: MongoNamespace) -> ThreadSafeMongoCollection<Document> {
        return localCollection(for: namespace, withType: Document.self)
    }

    /**
     Returns the local collection representing the given namespace.

     - parameter namespace: the namespace referring to the local collection.
     - parameter type: the type of document in this collection
     - returns: the local collection representing the given namespace.
     */
    private func localCollection<T: Codable>(for namespace: MongoNamespace,
                                             withType type: T.Type = T.self) -> ThreadSafeMongoCollection<T> {
        return localClient.db(DataSynchronizer.localUserDBName(for: namespace))
            .collection(namespace.collectionName, withType: type)
    }

    /**
     Returns the undo collection representing the given namespace for recording documents that
     may need to be reverted after a system failure.

     - parameter namespace: the namespace referring to the undo collection
     - returns: the undo collection representing the given namespace for recording documents that may need to be
     reverted after a system failure.
     */
    internal func undoCollection(for namespace: MongoNamespace) -> ThreadSafeMongoCollection<Document> {
        return localClient.db(
            DataSynchronizer.localUndoDBName(for: namespace)).collection(namespace.collectionName)
    }

    internal static func localUndoDBName(for namespace: MongoNamespace) -> String {
        return "sync_undo_\(namespace.databaseName)"
    }

    internal static func localConfigDBName(withInstanceKey instanceKey: String) -> String {
        return "sync_config_\(instanceKey.replacingOccurrences(of: "/", with: "_"))"
    }

    internal static func localUserDBName(for namespace: MongoNamespace) -> String {
        return "sync_user_\(namespace.databaseName)"
    }

    /**
     * Adds and returns a document with a new version to the given document.
     *
     * @param document   the document to attach a new version to.
     * @param newVersion the version to attach to the document
     * @return a document with a new version to the given document.
     */
    private static func withNewVersion(document: Document,
                                       newVersion: Document) -> Document {
        var copy = document
        copy[documentVersionField] = newVersion
        return copy
    }

    /**
     * Adds and returns a document with a new version to the given document.
     *
     * @param document   the document to attach a new version to.
     * @param newVersion the version to attach to the document
     * @return a document with a new version to the given document.
     */
    private static func updateDocument(forVersion: Document) -> Document {
        let update = ["$set": [documentVersionField: forVersion] as Document] as Document
        return update
    }
}

enum SyncMessage: CustomStringConvertible {
    case applyFromRemote
    case cannotParseRemoteVersion
    case deleteFromRemote
    case documentDeleted
    case duplicateKeyException
    case emptyVersion
    case emptyUpdateDescription
    case exceptionOnDelete(exception: String)
    case exceptionOnInsert(exception: String)
    case exceptionOnReplace(exception: String)
    case exceptionOnUpdate(exception: String)
    case expectedLocalDocumentToExist
    case instanceIdMismatch
    case pendingWriteDelete
    case pendingWriteEmptyVersion
    case probablyGeneratedByUs
    case remoteFindDeletedDoc
    case remoteFindFailed
    case remoteFindReplacedDoc
    case remoteUpdateWithoutVersion
    case simultaneousWrites
    case staleLocalWrite
    case staleEvent
    case staleProtocolVersion(version: Int)
    case unknownOptype(opType: OperationType)
    case unknownRemoteProtocolVersion(version: Int)
    case versionDifferentDeletedDoc
    case versionDifferentReplacedDoc
    case versionDifferentUnprocessedEvent
    case versionDifferentUpdatedDoc

    typealias Context = (logicalT: Int64, caller: String, namespace: MongoNamespace, documentId: AnyBSONValue)

    static let r2lMethod = "syncRemoteChangeEventToLocal"
    static let l2rMethod = "syncLocalToRemote"

    var description: String {
        switch self {
        case .applyFromRemote:
            return "replacing local with remote document with new version as there are no local pending writes"
        case .cannotParseRemoteVersion:
            return "got a remote document that could not have its version info parsed"
        case .deleteFromRemote:
            return "deleting local as there are no local pending writes"
        case .documentDeleted:
            return "remote document successfully deleted"
        case .duplicateKeyException:
            return "duplicate key exception on insert"
        case .emptyVersion:
            return "remote or local have an empty version"
        case .emptyUpdateDescription:
            return "local change event update description is empty for UPDATE"
        case let .exceptionOnDelete(exception):
            return "exception on delete: \(exception)"
        case let .exceptionOnInsert(exception):
            return "exception on insert: \(exception)"
        case let .exceptionOnReplace(exception):
            return "exception on replace: \(exception)"
        case let .exceptionOnUpdate(exception):
            return "exception on update: \(exception)"
        case .expectedLocalDocumentToExist:
            return "expected document to exist for local change event"
        case .instanceIdMismatch:
            return "remote event created by different device from last seen event"
        case .pendingWriteDelete:
            return "remote delete but a write is pending"
        case .pendingWriteEmptyVersion:
            return "remote or local have an empty version but a write is pending"
        case .probablyGeneratedByUs:
            return "remote change event was generated by us"
        case .remoteFindDeletedDoc:
            return "remote event generated by a different client and latest document lookup indicates a remote delete occurred"
        case .remoteFindFailed:
            return "failed to retrieve latest version of document from remote database"
        case .remoteFindReplacedDoc:
            return "latest document lookup indicates a remote replace occurred"
        case .remoteUpdateWithoutVersion:
            return "remote document changed but version was unmodified"
        case .simultaneousWrites:
            return "has multiple events at same logical time"
        case .staleLocalWrite:
            return "remote event version has higher counter than local pending write"
        case .staleEvent:
            return "remote change event is stale"
        case let .staleProtocolVersion(version):
            return "last seen change event has an unsupported synchronization protocol version \(version)"
        case let .unknownOptype(opType):
            return "unknown operation type: \(opType.rawValue)"
        case let .unknownRemoteProtocolVersion(version):
            return "got a remote document with an unsupported synchronization protocol version \(version)"
        case .versionDifferentDeletedDoc:
            return "version different on removed document"
        case .versionDifferentReplacedDoc:
            return "version different on replaced document or document was deleted"
        case .versionDifferentUnprocessedEvent:
            return "version different on unprocessed change event for document"
        case .versionDifferentUpdatedDoc:
            return "version different on updated document or document was deleted"
        }
    }

    static func constructMessage(action: SyncAction, message: SyncMessage, context: Context) -> String {
        return "t='\(context.logicalT)': \(context.caller) ns=\(context.namespace) documentId=\(context.documentId) \(message); \(action)"
    }
}

enum SyncAction: CustomStringConvertible {
    case applyFromRemote
    case applyAndVersionFromRemote
    case conflict
    case deleteLocal
    case deleteLocalAndDesync
    case dropEvent
    case dropEventAndDesync
    case dropEventAndPause
    case remoteFind
    case wait

    var description: String {
        switch self {
        case .applyFromRemote, .applyAndVersionFromRemote:
            return "applying changes from the remote document"
        case .conflict:
            return "raising conflict"
        case .deleteLocal:
            return "applying the remote delete"
        case .deleteLocalAndDesync:
            return "deleting and desyncing the document"
        case .dropEvent:
            return "dropping the event"
        case .dropEventAndPause:
            return "dropping the event and pausing the document"
        case .dropEventAndDesync:
            return "dropping the event and desyncing the document"
        case .remoteFind:
            return "re-checking against remote collection"
        case .wait:
            return "waiting until next pass"
        }
    }
}
