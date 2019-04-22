// These linter exceptions should eventually go away, but they would require major refactoring.
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
// swiftlint:disable file_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length
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
    /// RW lock for the listeners
    private let listenersLock: ReadWriteLock
    /// Dispatch queue for one-off events
    private lazy var eventDispatchQueue = DispatchQueue.init(
        label: "eventEmission-\(self.instanceKey!)",
        qos: .default)
    /// Dispatch queue for long running sync loop
    private lazy var syncDispatchQueue = DispatchQueue.init(
        label: "synchronizer-\(self.instanceKey!)",
        qos: .background,
        autoreleaseFrequency: .inherit)
    /// Local logger
    private var logger: Log!
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
        self.listenersLock = ReadWriteLock(label: "listeners_\(service.serviceName ?? "mongodb-atlas")")

        self.appInfo = appInfo
        self.networkMonitor = appInfo.networkMonitor
        self.authMonitor = appInfo.authMonitor

        self.localClient = try ThreadSafeMongoClient(withAppInfo: appInfo)

        self.networkMonitor.add(networkStateDelegate: self)

        self.initWorkItem = DispatchWorkItem {
            do {
                try self.initialize(appInfo: appInfo)
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

    private func initialize(appInfo: StitchAppClientInfo) throws {
        self.configDb = localClient.db(DataSynchronizer.localConfigDBName(withInstanceKey: instanceKey))

        self.instancesColl = configDb.collection("instances",
                                                 withType: InstanceSynchronization.self)
        self.logger = Log.init(tag: "dataSynchronizer-\(instanceKey!)")

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

    func reinitialize(appInfo: StitchAppClientInfo) {
        // can't reinitialize until we're done initializing in the first place
        self.waitUntilInitialized()

        operationsGroup.blockAndWait()
        self.initWorkItem = DispatchWorkItem {
            do {
                try self.initialize(appInfo: appInfo)
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
                            guard let id = document["_id"] else { return }
                            result[AnyBSONValue(id)] = document
                        })

                // a. For each unprocessed change event
                for (id, event) in remoteChangeEvents {
                    logger.i("t='\(logicalT)': syncRemoteToLocal consuming event of type: \(event.operationType)")
                    guard let docConfig = nsConfig[id.value],
                        !docConfig.isPaused else {
                            continue
                    }

                    unseenIds.remove(id)
                    latestDocumentMap.removeValue(forKey: id)
                    try syncRemoteChangeEventToLocal(nsConfig: nsConfig, docConfig: docConfig, remoteChangeEvent: event)
                }

                // For synchronized documents that had no unprocessed change event, but were marked as
                // stale, synthesize a remote replace event to replace the local stale document with the
                // latest remote copy.
                for id in unseenIds {
                    guard let docConfig = nsConfig[id.value],
                        !docConfig.isPaused,
                        let doc = latestDocumentMap[id] else {
                            // means we aren't actually synchronizing on this remote doc
                            continue
                    }

                    try syncRemoteChangeEventToLocal(
                        nsConfig: nsConfig,
                        docConfig: docConfig,
                        remoteChangeEvent: ChangeEvents.changeEventForLocalReplace(
                            namespace: nsConfig.namespace,
                            documentId: id.value,
                            document: doc,
                            writePending: false)
                    )
                    docConfig.isStale = false
                }

                // For synchronized documents that had no unprocessed change event, and did not have a
                // latest version when stale documents were queried, synthesize a remote delete event to
                // delete the local document.
                latestDocumentMap.keys.forEach({unseenIds.remove($0)})
                for unseenId in unseenIds {
                    guard let docConfig = nsConfig[unseenId.value] else {
                        // means we aren't actually synchronizing on this remote doc
                        continue
                    }
                    guard docConfig.lastKnownRemoteVersion != nil, !docConfig.isPaused else {
                        docConfig.isStale = false
                        continue
                    }

                    try syncRemoteChangeEventToLocal(
                        nsConfig: nsConfig,
                        docConfig: docConfig,
                        remoteChangeEvent: ChangeEvents.changeEventForLocalDelete(
                            namespace: nsConfig.namespace,
                            documentId: unseenId.value,
                            writePending: docConfig.hasUncommittedWrites
                    ))

                    docConfig.isStale = false
                }
            }
        }

        logger.i("t='\(logicalT)': syncRemoteToLocal END")
    }

    private func syncRemoteChangeEventToLocal(nsConfig: NamespaceSynchronization,
                                              docConfig: CoreDocumentSynchronization,
                                              remoteChangeEvent: ChangeEvent<Document>) throws {
        if docConfig.hasUncommittedWrites && docConfig.lastResolution == logicalT {
            logger.i(
                "t='\(logicalT)': syncRemoteChangeEventToLocal have writes for \(docConfig.documentId) but happened at same t; "
                    + "waiting until next pass")
            return
        }

        logger.i("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) processing operation='\(remoteChangeEvent.operationType)'")

        let currentRemoteVersionInfo: DocumentVersionInfo?
        do {
            currentRemoteVersionInfo = try DocumentVersionInfo.getRemoteVersionInfo(
                remoteDocument: remoteChangeEvent.fullDocument ?? [:])
        } catch {
            try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)
            emitError(docConfig: docConfig,
                      error: DataSynchronizerError.decodingError("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) got a remote "
                        + "document that could not have its version info parsed "
                        + "; dropping the event, and desyncing the document"))
            return
        }

        if let version = currentRemoteVersionInfo?.version,
            version.syncProtocolVersion != 1 {
            try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)

            emitError(docConfig: docConfig,
                      error: DataSynchronizerError.unsupportedProtocolVersion("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) got a remote "
                        + "document with an unsupported synchronization protocol version "
                        + "\(String(describing: currentRemoteVersionInfo?.version?.syncProtocolVersion)); dropping the event, and desyncing the document"))

            return
        }

        // ii. If the version info for the unprocessed change event has the same GUID as the local
        //     document version GUID, and has a version counter less than or equal to the local
        //     document version version counter, drop the event, as it implies the event has already
        //     been applied to the local collection.
        if try docConfig.hasCommittedVersion(versionInfo: currentRemoteVersionInfo) {
            // Skip this event since we generated it.
            logger.i("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) remote change event was "
                + "generated by us; dropping the event")
            return
        }

        // iii. If the document does not have local writes pending, apply the change event to the local
        //      document and emit a change event for it.
        guard let uncommittedChangeEvent = docConfig.uncommittedChangeEvent else {
            switch remoteChangeEvent.operationType {
            case .replace, .update, .insert:
                guard let remoteDocument = remoteChangeEvent.fullDocument else {
                    emitError(docConfig: docConfig, error: DataSynchronizerError.documentDoesNotExist("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) got no remote document"))
                    return
                }
                logger.i(
                    "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) replacing local with "
                        + "remote document with new version as there are no local pending writes: \(remoteDocument)")
                try replaceOrUpsertOneFromRemote(
                    namespace: nsConfig.namespace,
                    documentId: docConfig.documentId.value,
                    remoteDocument: remoteDocument,
                    atVersion: DocumentVersionInfo.getDocumentVersionDoc(document: remoteDocument),
                coalescedOperationType: remoteChangeEvent.operationType)
            case .delete:
                logger.i(
                    "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) deleting local as "
                        + "there are no local pending writes")
                try deleteOneFromRemote(
                    namespace: nsConfig.namespace,
                    documentId: docConfig.documentId.value)
            default:
                emitError(docConfig: docConfig,
                          error: DataSynchronizerError.decodingError("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) unknown operation type "
                            + "occurred on the document: \(remoteChangeEvent.operationType); dropping the event"))
            }

            return
        }

        // At this point, we know there is a pending write for this document, so we will either drop
        // the event if we know it is already applied or we know the event is stale, or we will raise a
        // conflict.

        // iv. Otherwise, check if the version info of the incoming remote change event is different
        //     from the version of the local document.
        let lastKnownLocalVersionInfo = try DocumentVersionInfo.getLocalVersionInfo(docConfig: docConfig)

        // 1. If either the local document version or the remote change event version are empty, raise
        //    a conflict. The absence of a version is effectively a version, and a remote change event
        //    with no version indicates a document that may have been committed by another client not
        //    adhering to the mobile sync protocol.
        if lastKnownLocalVersionInfo.version == nil || currentRemoteVersionInfo?.version == nil {
            logger.i(
                "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) remote or local have an "
                    + "empty version but a write is pending; raising conflict")
            try resolveConflict(namespace: nsConfig.namespace,
                                uncommittedChangeEvent: uncommittedChangeEvent,
                                remoteEvent: remoteChangeEvent,
                                documentId: docConfig.documentId.value)
            return
        }

        // 2. Check if the GUID of the two versions are the same.
        guard let localVersion = lastKnownLocalVersionInfo.version,
            let remoteVersion = currentRemoteVersionInfo?.version else {
                return
        }
        if localVersion.instanceId == remoteVersion.instanceId {
            // a. If the GUIDs are the same, compare the version counter of the remote change event with
            //    the version counter of the local document
            if remoteVersion.versionCounter <= localVersion.versionCounter {
                // i. drop the event if the version counter of the remote event less than or equal to the
                // version counter of the local document
                logger.i(
                    "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) remote change event "
                        + "is stale; dropping the event")
                return
            } else {
                // ii. raise a conflict if the version counter of the remote event is greater than the
                //     version counter of the local document
                logger.i(
                    "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) remote event version "
                        + "has higher counter than local version but a write is pending; "
                        + "raising conflict")
                try resolveConflict(
                    namespace: nsConfig.namespace,
                    uncommittedChangeEvent: uncommittedChangeEvent,
                    remoteEvent: remoteChangeEvent,
                    documentId: docConfig.documentId.value)
                return
            }
        }

        // b.  If the GUIDs are different, do a full document lookup against the remote server to
        //     fetch the latest version (this is to guard against the case where the unprocessed
        //     change event is stale).
        guard let newestRemoteDocument: Document = try self.remoteCollection(for: nsConfig.namespace)
            .find(["_id": docConfig.documentId.value]).first() else {
                // i. If the document is not found with a remote lookup, this means the document was
                //    deleted remotely, so raise a conflict using a synthesized delete event as the remote
                //    change event.
                logger.i(
                    "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) remote event version "
                        + "stale and latest document lookup indicates a remote delete occurred, but "
                        + "a write is pending; raising conflict")
                try resolveConflict(
                    namespace: nsConfig.namespace,
                    uncommittedChangeEvent: uncommittedChangeEvent,
                    remoteEvent: ChangeEvents.changeEventForLocalDelete(
                        namespace: nsConfig.namespace,
                        documentId: docConfig.documentId.value,
                        writePending: docConfig.hasUncommittedWrites),
                    documentId: docConfig.documentId.value)
                return
        }

        guard let newestRemoteVersionInfo =
            try DocumentVersionInfo.getRemoteVersionInfo(remoteDocument: newestRemoteDocument) else {
                try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)
                emitError(docConfig: docConfig,
                          error: DataSynchronizerError.decodingError("t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) got a remote "
                            + "document that could not have its version info parsed "
                            + "; dropping the event, and desyncing the document"))
                return
        }

        // ii. If the current GUID of the remote document (as determined by this lookup) is equal
        //     to the GUID of the local document, drop the event. We’re believed to be behind in
        //     the change stream at this point.
        if newestRemoteVersionInfo.version != nil
            && newestRemoteVersionInfo.version?.instanceId == localVersion.instanceId {

            logger.i(
                "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) latest document lookup "
                    + "indicates that this is a stale event; dropping the event")
            return

        }

        // iii. If the current GUID of the remote document is not equal to the GUID of the local
        //      document, raise a conflict using a synthesized replace event as the remote change
        //      event. This means the remote document is a legitimately new document and we should
        //      handle the conflict.
        logger.i(
            "t='\(logicalT)': syncRemoteChangeEventToLocal ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) latest document lookup "
                + "indicates a remote replace occurred, but a local write is pending; raising "
                + "conflict with synthesized replace event")
        try resolveConflict(
            namespace: nsConfig.namespace,
            uncommittedChangeEvent: uncommittedChangeEvent,
            remoteEvent: ChangeEvents.changeEventForLocalReplace(
                namespace: nsConfig.namespace,
                documentId: docConfig.documentId.value,
                document: newestRemoteDocument,
                writePending: docConfig.hasUncommittedWrites),
            documentId: docConfig.documentId.value)
    }

    private func syncLocalToRemote() throws {
        logger.i(
            "t='\(logicalT)': syncLocalToRemote START")

        // 1. Run local to remote (L2R) sync routine
        // Search for modifications in each namespace.
        for nsConfig in syncConfig {
            try nsConfig.nsLock.write {
                let remoteColl: CoreRemoteMongoCollection<Document> = remoteCollection(for: nsConfig.namespace)

                // a. For each document that has local writes pending
                for docConfig in nsConfig {
                    guard !docConfig.isPaused,
                        let localChangeEvent = docConfig.uncommittedChangeEvent else {
                            continue
                    }
                    if docConfig.lastResolution == logicalT {
                        logger.i(
                            "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) has writes from current logicalT; "
                                + "waiting until next pass")
                        continue
                    }

                    // i. Retrieve the change event for this local document in the local config metadata
                    logger.i(
                        "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) processing operation='\(localChangeEvent.operationType)'")

                    let localDoc = localChangeEvent.fullDocument
                    let docFilter = ["_id": docConfig.documentId.value] as Document

                    var isConflicted = false

                    // This is here as an optimization in case an op requires we look up the remote document
                    // in advance and we only want to do this once.
                    var remoteDocument: Document?
                    var remoteDocumentFetched = false

                    let localVersionInfo =
                        try DocumentVersionInfo.getLocalVersionInfo(docConfig: docConfig)
                    var nextVersion: Document?

                    // ii. Check if the internal remote change stream listener has an unprocessed event for
                    //     this document.
                    if let unprocessedRemoteEvent =
                        instanceChangeStreamDelegate[nsConfig.namespace]?.unprocessedEvent(for: docConfig.documentId.value) {
                        let unprocessedEventVersion: DocumentVersionInfo?
                        do {
                            unprocessedEventVersion = try DocumentVersionInfo.getRemoteVersionInfo(remoteDocument: unprocessedRemoteEvent.fullDocument ?? [:])
                        } catch {
                            try self.desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)
                            self.emitError(docConfig: docConfig,
                                      error: DataSynchronizerError.decodingError("t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) got a remote "
                                        + "document that could not have its version info parsed "
                                        + "; dropping the event, and desyncing the document"))
                            continue
                        }

                        // 1. If it does and the version info is different, record that a conflict has occurred.
                        //    Difference is determined if either the GUID is different or the version counter is
                        //    greater than the local version counter, or if both versions are empty
                        if try !docConfig.hasCommittedVersion(versionInfo: unprocessedEventVersion) {
                            isConflicted = true
                            logger.i(
                                "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) version different on "
                                    + "unprocessed change event for document; raising conflict")
                        }

                        // 2. Otherwise, the unprocessed event can be safely dropped and ignored in future R2L
                        //    passes. Continue on to checking the operation type.
                    }

                    if !isConflicted {
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
                                    DataSynchronizer.withNewVersion(document: localChangeEvent.fullDocument!,
                                                                    newVersion: nextVersion!))
                            } catch {
                                // b. If an error happens:

                                // i. That is not a duplicate key exception, report an error to the error
                                // listener.
                                guard let err = error as? StitchError,
                                    case .serviceError(let msg, let code) = err,
                                    code == .mongoDBError, msg.contains("E11000") else {
                                        self.emitError(docConfig: docConfig, error: DataSynchronizerError.mongoDBError(
                                            "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) exception inserting: \(error)", error))
                                        continue
                                }

                                // ii. Otherwise record that a conflict has occurred.
                                logger.i(
                                    "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) duplicate key exception on "
                                        + "insert; raising conflict")
                                isConflicted = true
                            }
                        // 2. REPLACE
                        case .replace:
                            guard let localDoc = localDoc else {
                                self.emitError(
                                    docConfig: docConfig,
                                    error: DataSynchronizerError.documentDoesNotExist(
                                        "expected document to exist for local replace change event: %s")
                                )
                                continue
                            }
                            nextVersion = localVersionInfo.nextVersion
                            let nextDoc = DataSynchronizer.withNewVersion(document: localDoc, newVersion: nextVersion!)

                            // a. Update the document in the remote database using a query for the _id and the
                            //    version with an update containing the replacement document with the version
                            //    counter incremented by 1.
                            let result: RemoteUpdateResult
                            do {
                                result = try remoteColl.updateOne(
                                    filter: localVersionInfo.filter!,
                                    update: nextDoc)
                            } catch {
                                // b. If an error happens, report an error to the error listener.
                                self.emitError(
                                    docConfig: docConfig,
                                    error: DataSynchronizerError.mongoDBError("t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) exception "
                                        + "replacing", error))
                                continue
                            }
                            // c. If no documents are matched, record that a conflict has occurred.
                            if result.matchedCount == 0 {
                                isConflicted = true
                                logger.i(
                                    "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) version different on "
                                        + "replaced document or document deleted; raising conflict")
                            }

                        // 3. UPDATE
                        case .update:
                            guard localDoc != nil else {
                                self.emitError(
                                    docConfig: docConfig,
                                    error: DataSynchronizerError.documentDoesNotExist(
                                        "expected document to exist for local update change event")
                                )
                                continue
                            }

                            guard let localUpdateDescription = localChangeEvent.updateDescription,
                                (!localUpdateDescription.removedFields.isEmpty ||
                                    !localUpdateDescription.updatedFields.isEmpty) else {
                                        // if the translated update is empty, then this update is a noop, but
                                        // we should still increment the version information.
                                        logger.i("t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) local change event "
                                            + "update description is empty for UPDATE; dropping the event")
                                        try docConfig.setPendingWritesComplete(atVersion: localVersionInfo.nextVersion)
                                        continue
                            }

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
                            let result: RemoteUpdateResult
                            do {
                                result = try remoteColl.updateOne(
                                    filter: localVersionInfo.filter!,
                                    update: translatedUpdate
                                )
                            } catch {
                                // b. If an error happens, report an error to the error listener.
                                emitError(
                                    docConfig: docConfig,
                                    error: DataSynchronizerError.mongoDBError(
                                        "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) exception "
                                            + "updating)", error))
                                continue
                            }
                            if result.matchedCount == 0 {
                                // c. If no documents are matched, record that a conflict has occurred.
                                isConflicted = true
                                logger.i(
                                    "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) version different on "
                                        + "updated document or document deleted; raising conflict")
                            }
                        case .delete:
                            nextVersion = nil
                            let result: RemoteDeleteResult
                            // a. Delete the document in the remote database using a query for the _id and the
                            //    version.
                            do {
                                result = try remoteColl.deleteOne(localVersionInfo.filter!)
                            } catch {
                                // b. If an error happens, report an error to the error listener.
                                self.emitError(
                                    docConfig: docConfig,
                                    error: DataSynchronizerError.mongoDBError("t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) exception "
                                        + " deleting", error))
                                continue
                            }
                            // c. If no documents are matched, record that a conflict has occurred.
                            if result.deletedCount == 0 {
                                remoteDocument = try remoteColl.find(docFilter).first()
                                remoteDocumentFetched = true
                                if remoteDocument != nil {
                                    isConflicted = true
                                    logger.i(
                                        "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) version different on "
                                            + "removed document; raising conflict")
                                } else {
                                    // d. Desynchronize the document if there is no conflict, or if fetching a
                                    // remote document after the conflict is raised returns no remote document.
                                    try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)
                                }
                            } else {
                                try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: docConfig.documentId.value)
                            }
                        default:
                            self.emitError(
                                docConfig: docConfig,
                                error: DataSynchronizerError.decodingError(
                                    "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) unknown operation "
                                        + "type occurred on the document: \(localChangeEvent.operationType); dropping the event")
                            )
                            continue
                        }
                    } else {
                        nextVersion = nil
                    }

                    logger.i(
                        "t='\(logicalT)': syncLocalToRemote ns=\(nsConfig.namespace) documentId=\(docConfig.documentId) conflict=\(isConflicted)")

                    if !isConflicted {
                        // iv. If no conflict has occurred, move on to the remote to local sync routine.

                        // since we strip version information from documents before setting pending writes, we
                        // don't have to worry about a stale document version in the event here.
                        let committedEvent = docConfig.uncommittedChangeEvent!
                        self.emitEvent(documentId: docConfig.documentId.value, event: ChangeEvent<Document>(
                            id: committedEvent.id,
                            operationType: committedEvent.operationType,
                            fullDocument: committedEvent.fullDocument,
                            ns: committedEvent.ns,
                            documentKey: committedEvent.documentKey,
                            updateDescription: committedEvent.updateDescription,
                            hasUncommittedWrites: false))

                        try docConfig.setPendingWritesComplete(atVersion: nextVersion)
                    } else {
                        // v. Otherwise, invoke the collection-level conflict handler with the local change
                        // event and the remote change event (synthesized by doing a lookup of the document or
                        // sourced from the listener)
                        let remoteChangeEvent: ChangeEvent<Document>
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
                        try self.resolveConflict(
                            namespace: nsConfig.namespace,
                            uncommittedChangeEvent: docConfig.uncommittedChangeEvent!,
                            remoteEvent: remoteChangeEvent,
                            documentId: docConfig.documentId.value)
                    }
                }
            }
        }
        logger.i("t='\(logicalT)': syncLocalToRemote END")

        // 3. If there are still local writes pending for the document, it will go through the L2R
        //    phase on a subsequent pass and try to commit changes again.
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
            for: try remoteColl.find(["_id": documentId]).first())
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
    private func resolveConflict(namespace: MongoNamespace,
                                 uncommittedChangeEvent: ChangeEvent<Document>,
                                 remoteEvent: ChangeEvent<Document>,
                                 documentId: BSONValue) throws {
        guard let nsConfig = syncConfig[namespace],
            let conflictHandler = nsConfig.conflictHandler,
            let docConfig = syncConfig[namespace]?[documentId] else {
                logger.f("t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) no conflict resolver set; cannot "
                    + "resolve yet")
                return
        }

        logger.i(
            "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) resolving conflict between localOp=\(uncommittedChangeEvent.operationType) "
                + "remoteOp=\(remoteEvent.operationType)")

        // 2. Based on the result of the handler determine the next state of the document.

        var resolvedDocument: Document?
        do {
            // no need to transform the change events for the user, since the conflict handler data structure
            // will take care of that already.
            resolvedDocument = try DataSynchronizer.resolveConflictWithResolver(
                conflictResolver: conflictHandler,
                documentId: documentId,
                localEvent: uncommittedChangeEvent,
                remoteEvent: remoteEvent)
        } catch {
            let errorString = "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) resolution "
                + "exception: \(error.localizedDescription))"
            logger.e(errorString)
            emitError(docConfig: docConfig, error: .resolutionError(error))
            return
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
                try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: documentId)
                emitError(docConfig: docConfig, error: .decodingError(
                    "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) got a remote "
                        + "document that could not have its version info parsed "
                        + "; dropping the event, and desyncing the document"
                ))
                return
            }
        }

        var sanitizedRemoteDocument: Document?
        if let remoteDocument = remoteEvent.fullDocument {
            sanitizedRemoteDocument = DataSynchronizer.sanitizeDocument(remoteDocument)
        }

        let acceptRemote = (sanitizedRemoteDocument == nil && resolvedDocument == nil)
            || (sanitizedRemoteDocument != nil
                && sanitizedRemoteDocument?.bsonEquals(resolvedDocument) ?? false)

        // a. If the resolved document is not nil:
        if let docForStorage = resolvedDocument {
            // Update the document locally which will keep the pending writes but with
            // a new version next time around.
            logger.i(
                "t='\(logicalT)': resolveConflict ns=\(namespace) documentId=\(documentId) replacing local with resolved document "
                    + "with remote version acknowledged: \(docForStorage)")
            if acceptRemote {
                // i. If the remote document is equal to the resolved document, replace the document
                //    locally, mark the document as having no pending writes, and emit a REPLACE change
                //    event if the document had not existed prior, or UPDATE if it had.
                try self.replaceOrUpsertOneFromRemote(
                    namespace: namespace,
                    documentId: documentId,
                    remoteDocument: docForStorage,
                    atVersion: remoteVersion,
                    coalescedOperationType: remoteEvent.operationType)
            } else {
                // ii. Otherwise, replace the local document with the resolved document locally, mark that
                //     there are pending writes for this document, and emit an UPDATE change event, or a
                //     DELETE change event (if the remoteEvent's operation type was DELETE).
                try self.updateOrUpsertOneFromResolution(
                    namespace: namespace,
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
                try self.deleteOneFromRemote(namespace: namespace, documentId: documentId)
            } else {
                // ii. Otherwise, delete the document locally, mark that there are pending writes for this
                //     document, and emit a change event for the deletion.
                try self.deleteOneFromResolution(namespace: namespace, documentId: documentId, atVersion: remoteVersion)
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
    internal func desyncDocumentFromRemote(nsConfig: NamespaceSynchronization,
                                           documentId: BSONValue,
                                           shouldTriggerListening: Bool = true) throws {
        self.waitUntilInitialized()
        self.operationsGroup.enter()
        defer { self.operationsGroup.leave() }

        nsConfig.nsLock.assertWriteLocked()

        // remove the synchronized document from the nsConfig
        nsConfig[documentId] = nil

        // delete the document from the local collection
        try self.localCollection(for: nsConfig.namespace,
                                 withType: Document.self).deleteOne(["_id": documentId])

        if shouldTriggerListening {
            self.triggerListening(to: nsConfig.namespace)
        }
    }

    /**
     * Replaces a single synchronized document by its given id with the given full document
     * replacement. No replacement will occur if the _id is not being synchronized.
     *
     * @param namespace  the namespace where the document lives.
     * @param documentId the _id of the document.
     * @param remoteDocument   the replacement document.
     */
    private func replaceOrUpsertOneFromRemote(namespace: MongoNamespace ,
                                              documentId: BSONValue,
                                              remoteDocument: Document,
                                              atVersion: Document?,
                                              coalescedOperationType: OperationType) throws {
        guard let lock = syncConfig[namespace]?.nsLock else {
            return
        }

        lock.assertWriteLocked()
        guard let config = syncConfig[namespace]?[documentId] else {
            return
        }

        let localCollection = self.localCollection(for: namespace, withType: Document.self)

        let undoCollection = self.undoCollection(for: namespace)

        let documentBeforeUpdate = try localCollection.find([idField: documentId],
                                                            options: nil).next()
        if var documentBeforeUpdate = documentBeforeUpdate {
            try undoCollection.insertOne(&documentBeforeUpdate)
        }

        // Since we are accepting the remote document as the resolution to the conflict, it may
        // contain version information. Clone the document and remove forbidden fields from it before
        // storing it in the collection.
        let docForStorage = DataSynchronizer.sanitizeDocument(remoteDocument)

        try localCollection.findOneAndReplace(filter: ["_id": documentId],
                                              replacement: docForStorage,
                                              options: FindOneAndReplaceOptions(upsert: true))
        try config.setPendingWritesComplete(atVersion: atVersion)

        if documentBeforeUpdate != nil {
            try undoCollection.deleteOne([idField: documentId])
        }

        var event: ChangeEvent<Document>
        if coalescedOperationType == .update, let documentBeforeUpdate = documentBeforeUpdate {
            event = ChangeEvents.changeEventForLocalUpdate(namespace: namespace,
                                                                    documentId: documentId,
                                                                    update: documentBeforeUpdate.diff(otherDocument: docForStorage),
                                                                    fullDocumentAfterUpdate: docForStorage,
                                                                    writePending: false)
        } else {
            event = ChangeEvents.changeEventForLocalReplace(
                namespace: namespace,
                documentId: documentId,
                document: docForStorage,
                updateDescription: nil,
                writePending: false)
        }
        self.emitEvent(documentId: documentId, event: event)
    }

    /**
     * Replaces a single synchronized document by its given id with the given full document
     * replacement. No replacement will occur if the _id is not being synchronized.
     *
     * @param namespace  the namespace where the document lives.
     * @param documentId the _id of the document.
     * @param document   the replacement document.
     */
    private func updateOrUpsertOneFromResolution(namespace: MongoNamespace,
                                                 documentId: BSONValue,
                                                 document: Document,
                                                 atVersion: Document?,
                                                 remoteEvent: ChangeEvent<Document>) throws {
        guard let lock = syncConfig[namespace]?.nsLock else {
            return
        }

        lock.assertWriteLocked()
        guard let config = syncConfig[namespace]?[documentId] else {
            return
        }

        let localCollection = self.localCollection(for: namespace, withType: Document.self)
        let undoCollection = self.undoCollection(for: namespace)

        let documentBeforeUpdate = try localCollection.find([idField: documentId], options: nil).next()

        if var documentBeforeUpdate = documentBeforeUpdate {
            try undoCollection.insertOne(&documentBeforeUpdate)
        }

        // Remove forbidden fields from the resolved document before it will updated/upserted in the
        // local collection.
        let docForStorage = DataSynchronizer.sanitizeDocument(document)

        guard let documentAfterUpdate = try localCollection
            .findOneAndReplace(
                filter: ["_id": documentId],
                replacement: docForStorage,
                options: FindOneAndReplaceOptions(returnDocument: .after, upsert: true)) else {
                    return
        }

        let event: ChangeEvent<Document>
        if remoteEvent.operationType == .delete {
            event = ChangeEvents.changeEventForLocalInsert(namespace: namespace,
                                                                    document: documentAfterUpdate,
                                                                    documentId: documentId,
                                                                    writePending: true)
        } else {
            guard let unsanitizedRemoteDocument = remoteEvent.fullDocument else {
                return
            }

            let remoteDocument = DataSynchronizer.sanitizeDocument(unsanitizedRemoteDocument)
            event = ChangeEvents.changeEventForLocalUpdate(
                namespace: namespace,
                documentId: documentId,
                update: remoteDocument.diff(otherDocument: documentAfterUpdate),
                fullDocumentAfterUpdate: docForStorage,
                writePending: true)
        }
        try config.setSomePendingWrites(
            atTime: logicalT,
            atVersion: atVersion,
            changeEvent: event)

        if documentBeforeUpdate != nil {
            try undoCollection.deleteOne([idField: documentId])
        }

        self.emitEvent(documentId: documentId, event: event)
    }

    /**
     * Deletes a single synchronized document by its given id. No deletion will occur if the _id is
     * not being synchronized.
     *
     * @param namespace  the namespace where the document lives.
     * @param documentId the _id of the document.
     */
    private func deleteOneFromRemote(namespace: MongoNamespace, documentId: BSONValue) throws {
        guard let nsConfig = syncConfig[namespace] else {
            return
        }

        nsConfig.nsLock.assertWriteLocked()

        guard syncConfig[namespace]?[documentId] != nil else {
            return
        }

        let localCollection = self.localCollection(for: namespace, withType: Document.self)

        let undoCollection = self.undoCollection(for: namespace)

        guard var documentToDelete = try localCollection.find([idField: documentId]).next() else {
            try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: documentId)
            return
        }

        try undoCollection.insertOne(&documentToDelete)
        try localCollection.deleteOne([idField: documentId])
        try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: documentId)
        try undoCollection.deleteOne([idField: documentId])

        self.emitEvent(documentId: documentId,
                       event: ChangeEvents.changeEventForLocalDelete(
                        namespace: namespace,
                        documentId: documentId,
                        writePending: false))
    }

    private func deleteOneFromResolution(namespace: MongoNamespace,
                                         documentId: BSONValue,
                                         atVersion: Document?) throws {
        guard let lock = syncConfig[namespace]?.nsLock else {
            return
        }

        lock.assertWriteLocked()

        guard let config = syncConfig[namespace]?[documentId] else {
            return
        }
        let localCollection = self.localCollection(for: namespace, withType: Document.self)
        let undoCollection = self.undoCollection(for: namespace)

        let documentToDelete = try localCollection.find([idField: documentId], options: nil).next()
        if var documentToDelete = documentToDelete {
            try undoCollection.insertOne(&documentToDelete)
        }

        try localCollection.deleteOne(["_id": documentId])
        let event = ChangeEvents.changeEventForLocalDelete(namespace: namespace, documentId: documentId, writePending: true)
        try config.setSomePendingWrites(atTime: logicalT, atVersion: atVersion, changeEvent: event)

        if documentToDelete != nil {
            try undoCollection.deleteOne([idField: documentId])
        }

        self.emitEvent(documentId: documentId, event: event)
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

        try ids.forEach { id in
            guard let nsConfig = syncConfig[namespace] else {
                return
            }

            try syncLock.write {
                try nsConfig.nsLock.write {
                    try desyncDocumentFromRemote(nsConfig: nsConfig, documentId: id, shouldTriggerListening: false)
                }
            }
        }

        // wrap in a synclock since triggerListening expects to be syncLocked
        syncLock.write {
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
            try config.setSomePendingWrites(atTime: logicalT, changeEvent: event)
            return (event, result)
        }) else {
            return nil
        }

        syncLock.write {
            self.triggerListening(to: namespace)
        }

        self.emitEvent(documentId: result.insertedId, event: event)
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
                try config.setSomePendingWrites(atTime: logicalT, changeEvent: event)
                return { self.emitEvent(documentId: documentId, event: event) }
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

            try docConfig.setSomePendingWrites(atTime: logicalT, changeEvent: event)

            try undoColl.deleteOne([idField: docConfig.documentId.value])

            emitEvent = { self.emitEvent(documentId: documentId, event: event) }

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

                try docConfig.setSomePendingWrites(atTime: logicalT, changeEvent: event)
                try undoColl.deleteOne([idField: documentId])
                deferredBlocks.append { self.emitEvent(documentId: documentId, event: event) }
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

            try config.setSomePendingWrites(atTime: logicalT, changeEvent: event)

            if let documentIdBeforeUpdate = documentBeforeUpdate?[idField] {
                try undoColl.deleteOne([idField: documentIdBeforeUpdate])
            }

            emitEvent = { self.emitEvent(documentId: documentId, event: event) }

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

                deferredBlocks.append { self.emitEvent(documentId: documentId, event: event) }
                try config.setSomePendingWrites(atTime: logicalT, changeEvent: event)
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

    /**
     Emits a change event for the given document id.

     - parameter documentId: the document that has a change event for it.
     - parameter event:      the change event.
     */
    private func emitEvent(documentId: BSONValue, event: ChangeEvent<Document>) {
        listenersLock.write {
            let nsConfig = syncConfig[event.ns]

            eventDispatchQueue.async {
                nsConfig?.changeEventDelegate?.onEvent(documentId: documentId,
                                                       event: event)
            }
        }
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

    /**
     Emits an error for the given document id. This should be used
     for irrecoverable errors. Pauses the doc config.
     - parameter docConfig: document configuration the error occured on
     - parameter error: the error that occured
     */
    private func emitError(docConfig: CoreDocumentSynchronization,
                           error: DataSynchronizerError) {
        let documentId = docConfig.documentId.value
        docConfig.isPaused = true
        logger.e(error.localizedDescription)
        logger.e("Setting document to frozen: \(docConfig.documentId.value)")

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
            .find(["_id": ["$in": ids] as Document]).toArray()
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
}
