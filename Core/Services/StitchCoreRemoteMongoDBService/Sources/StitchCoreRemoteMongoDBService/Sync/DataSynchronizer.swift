import Foundation
import MongoSwift
import MongoMobile
import StitchCoreSDK

/**
 DataSynchronizer handles the bidirectional synchronization of documents between a local MongoDB
 and a remote MongoDB (via Stitch). It also expose CRUD operations to interact with synchronized
 documents.
 */
public class DataSynchronizer: NetworkStateListener, FatalErrorListener {
    /// The amount of time to sleep between sync passes in a non-error state.
    fileprivate static let shortSleepSeconds: UInt32 = 1
    /// The amount of time to sleep between sync passes in an error-state.
    fileprivate static let longSleepSeconds: UInt32 = 5

    /// The unique instance key for this DataSynchronizer
    private let instanceKey: String
    /// The associated service client
    private let service: CoreStitchServiceClient
    /// The associated embedded client
    private let localClient: MongoClient
    /// The associated remote client
    private let remoteClient: CoreRemoteMongoClient
    /// Network monitor that receives to network state
    private let networkMonitor: NetworkMonitor
    /// Auth monitor that receives auth state
    private let authMonitor: AuthMonitor
    /// Database to manage our configurations
    private let configDb: MongoDatabase
    /// The collection to store the configuration for this instance in
    private let instancesColl: MongoCollection<InstanceSynchronization.Config>
    /// The configuration for this sync instance
    private var syncConfig: InstanceSynchronization

    /// Whether or not the DataSynchronizer has been configured
    private(set) var isConfigured = false
    /// Whether or not the sync thread is enabled
    private(set) var isSyncThreadEnabled = true

    /// RW lock for the synchronizer
    private let syncLock = ReadWriteLock()
    /// RW lock for the listeners
    private let listenersLock = ReadWriteLock()
    /// Dispatch queue for one-off events
    private lazy var eventDispatchQueue = DispatchQueue.init(
        label: "eventEmission-\(self.instanceKey)",
        qos: .default,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit)
    /// Dispatch queue for long running sync loop
    private lazy var syncDispatchQueue = DispatchQueue.init(
        label: "synchronizer-\(self.instanceKey)",
        qos: .background,
        autoreleaseFrequency: .inherit)
    /// Local logger
    private let log: Log
    /// The current work item running the sync loop
    private var syncWorkItem: DispatchWorkItem? = nil
    /// The user's error listener
    private var errorListener: ErrorListener?
    /// Current sync pass iteration
    private var logicalT: Int = 0
    /// Whether or not the sync loop is running
    var isRunning: Bool {
        syncLock.readLock()
        defer { syncLock.unlock() }
        return syncWorkItem != nil && syncWorkItem?.isCancelled == false
    }
    
    public init(instanceKey: String,
                service: CoreStitchServiceClient,
                localClient: MongoClient,
                remoteClient: CoreRemoteMongoClient,
                networkMonitor: NetworkMonitor,
                authMonitor: AuthMonitor) throws {
        self.instanceKey = instanceKey
        self.service = service
        self.localClient = localClient
        self.remoteClient = remoteClient
        self.networkMonitor = networkMonitor
        self.authMonitor = authMonitor

        self.configDb = try localClient.db(DataSynchronizer.localConfigDBName(withInstanceKey: instanceKey))

        self.instancesColl = try configDb.collection("instances",
                                                     withType: InstanceSynchronization.Config.self)
        self.log = Log.init(tag: "dataSynchronizer-\(instanceKey)")

        if try instancesColl.count() == 0 {
            self.syncConfig = try InstanceSynchronization(configDb: configDb,
                                                          errorListener: nil)
            try instancesColl.insertOne(self.syncConfig.config)
        } else {
            if try instancesColl.find().next() == nil {
                throw StitchError.clientError(
                    withClientErrorCode: StitchClientErrorCode.couldNotLoadSyncInfo)
            }
            self.syncConfig = try InstanceSynchronization(configDb: configDb,
                                                          errorListener: nil)
        }

        self.syncConfig.errorListener = self
        self.networkMonitor.add(networkStateListener: self)
    }

    public func onNetworkStateChanged() {
        if (!self.networkMonitor.isConnected()) {
            self.stop()
        } else {
            self.start()
        }
    }

    public func configure<CH: ConflictHandler, CEL: ChangeEventListener>(namespace: MongoNamespace,
                                                                         conflictHandler: CH,
                                                                         changeEventListener: CEL,
                                                                         errorListener: ErrorListener) {
        self.errorListener = errorListener

        guard var nsConfig = self.syncConfig[namespace] else {
            return
        }

        syncLock.writeLock()
        defer { syncLock.unlock() }

        nsConfig.configure(conflictHandler: conflictHandler,
                           changeEventListener: changeEventListener)

        if (!self.isConfigured) {
            self.isConfigured = true
            syncLock.unlock()
            self.triggerListening(to: nsConfig.config.namespace)
        } else {
            syncLock.unlock()
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
        syncLock.writeLock()
        defer { syncLock.unlock() }

        // TODO STITCH-2217 Stop listeners
        if try instancesColl.find().next() == nil {
            throw StitchError.serviceError(withMessage: "expected to find instance configuration",
                                           withServiceErrorCode: .unknown)
        }

        self.syncConfig = try InstanceSynchronization(configDb: configDb, errorListener: self)
        self.isConfigured = false
        self.stop()
    }

    func doSyncPass() -> Bool {
        // TODO Sync Logic
        return true
    }

    /**
     Starts data synchronization in a background thread.
     */
    public func start() {
        syncLock.writeLock()
        defer { syncLock.unlock() }
        if (!self.isConfigured) {
            return
        }

        // TODO STITCH-2217: restart changestream listeners
        if isSyncThreadEnabled {
            self.syncWorkItem = DispatchWorkItem { [weak self] in
                repeat {
                    guard let dataSync = self else {
                        return
                    }

                    var successful = false
                    successful = dataSync.doSyncPass()

                    if (successful) {
                        sleep(DataSynchronizer.shortSleepSeconds)
                    } else {
                        sleep(DataSynchronizer.longSleepSeconds)
                    }
                } while self?.syncWorkItem?.isCancelled == false 
            }

            syncDispatchQueue.async(execute: self.syncWorkItem!)
        }
    }

    /**
     Stops the background data synchronization thread.
     */
    public func stop() {
        syncLock.writeLock()
        defer { syncLock.unlock() }

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
    func sync(ids: [BSONValue], in namespace: MongoNamespace) {
        ids.forEach { id in
            guard var nsConfig = syncConfig[namespace] else {
                return
            }

            nsConfig.sync(id: id)
        }

        self.triggerListening(to: namespace)
    }

    /**
     Stops synchronizing the given document _ids. Any uncommitted writes will be lost.

     - parameter ids: the _ids of the documents to desynchronize.
     */
    func desync(ids: [BSONValue], in namespace: MongoNamespace) {
        ids.forEach { id in
            guard var namespace = syncConfig[namespace] else {
                return
            }

            namespace[id] = nil
        }

        self.triggerListening(to: namespace)
    }

    /**
     Returns the set of synchronized document ids in a namespace.

     TODO Remove custom HashableBSONValue after: https://jira.mongodb.org/browse/SWIFT-255
     - returns: the set of synchronized document ids in a namespace.
     */
    func syncedIds(in namespace: MongoNamespace) -> Set<HashableBSONValue> {
        guard let nsConfig = syncConfig[namespace] else {
            return Set()
        }

        let v = nsConfig.map { $0.documentId }
        return Set(nsConfig.map({HashableBSONValue($0.documentId)}))
    }

    /**
     Return the set of synchronized document _ids in a namespace
     that have been paused due to an irrecoverable error.

     - returns: the set of paused document _ids in a namespace
     */
    func pausedIds(in namespace: MongoNamespace) -> Set<HashableBSONValue> {
        guard let nsConfig = syncConfig[namespace] else {
            return Set()
        }

        return Set(nsConfig.compactMap { docConfig in
            guard docConfig.isPaused else {
                return nil
            }
            return HashableBSONValue(docConfig.documentId)
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
        guard var nsConfig = syncConfig[namespace],
            var docConfig = nsConfig[documentId] else {
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
               options: CountOptions?,
               in namespace: MongoNamespace) throws -> Int {
        let lock = self.syncConfig[namespace]?.nsLock ?? syncLock
        lock.readLock()
        defer { lock.unlock() }

        return try localCollection(for: namespace, withType: Document.self)
            .count(filter, options: options)
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
                                  options: FindOptions?,
                                  in namespace: MongoNamespace) throws -> MongoCursor<DocumentT> {
        let lock = self.syncConfig[namespace]?.nsLock ?? syncLock
        lock.readLock()
        defer { lock.unlock() }

        return try localCollection(for: namespace).find(filter, options: options)
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
        let lock = self.syncConfig[namespace]?.nsLock ?? syncLock
        lock.readLock()
        defer { lock.unlock() }

        return try localCollection(for: namespace, withType: Document.self).aggregate(
            pipeline,
            options: options)
    }



    /**
     Inserts the provided document. If the document is missing an identifier, the client should
     generate one. Syncs the newly inserted document against the remote.

     - parameter document: the document to insert
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the insert one operation
     */
    func insertOne<DocumentT: Codable>(document: DocumentT,
                                       in namespace: MongoNamespace) -> InsertOneResult? {
        fatalError("\(#function) not implemented")
    }

    /**
     Inserts one or more documents. Syncs the newly inserted documents against the remote.

     - parameter documents: the documents to insert
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the insert many operation
     */
    func insertMany<DocumentT: Codable>(documents: DocumentT...,
        in namespace: MongoNamespace) -> InsertManyResult? {
        fatalError("\(#function) not implemented")
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
                   in namespace: MongoNamespace) -> DeleteResult? {
        fatalError("\(#function) not implemented")
    }

    /**
     Removes all documents from the collection that have been synchronized with the remote
     that match the given query filter.  If no documents match, the collection is not modified.

     - parameter filter: the query filter to apply the the delete operation
     - parameter namespace: the namespace to conduct this op
     - returns: the result of the remove many operation
     */
    func deleteMany(filter: Document,
                    in namespace: MongoNamespace) -> DeleteResult? {
        fatalError("\(#function) not implemented")
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
                   options: UpdateOptions?,
                   in namespace: MongoNamespace) -> UpdateResult? {
        fatalError("\(#function) not implemented")
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
                    options: UpdateOptions?,
                    in namespace: MongoNamespace) -> UpdateResult? {
        fatalError("\(#function) not implemented")
    }

    /**
     Emits a change event for the given document id.

     - parameter documentId: the document that has a change event for it.
     - parameter event:      the change event.
     */
    private func emitEvent(documentId: BSONValue, event: ChangeEvent<Document>) {
        listenersLock.readLock()
        defer { listenersLock.unlock() }

        let nsConfig = syncConfig[event.ns]

        eventDispatchQueue.async {
            nsConfig?.changeEventListener?.onEvent(documentId: documentId,
                                                   event: event)
        }
    }

    /// Potentially pass along useful error information to the user.
    /// This should only be used for low level errors.
    func on(error: Error, forDocumentId documentId: BSONValue?, in namespace: MongoNamespace?) {
        guard let errorListener = self.errorListener else {
            return
        }

        guard let unwrappedNamespace = namespace, let unwrappedDocumentId = documentId else {
            log.e(error.localizedDescription)
            log.e("Fatal error occured: \(error.localizedDescription)")
            self.eventDispatchQueue.async {
                errorListener.on(error: error, forDocumentId: documentId)
            }
            return
        }

        guard var config = syncConfig[unwrappedNamespace]?[unwrappedDocumentId] else {
            log.e(error.localizedDescription)
            log.e("Fatal error occured in namespace \(unwrappedNamespace) " +
                "for documentId \(unwrappedDocumentId): \(error.localizedDescription)")
            self.eventDispatchQueue.async {
                errorListener.on(error: error, forDocumentId: documentId)
            }
            return
        }

        emitError(docConfig: &config, error: error)
    }

    /**
     Emits an error for the given document id. This should be used
     for irrecoverable errors. Pauses the doc config.
     - parameter docConfig: document configuration the error occured on
     - parameter error: the error that occured
     */
    private func emitError(docConfig: inout CoreDocumentSynchronization,
                           error: Error) {
        guard let errorListener = self.errorListener else {
            return
        }

        let documentId = docConfig.documentId.value
        self.eventDispatchQueue.async {
            errorListener.on(error: error, forDocumentId: documentId)
        }

        docConfig.isPaused = true
        log.e(error.localizedDescription)
        log.e("Setting document to frozen: \(docConfig.documentId.value)")
    }

    /**
     Trigger change stream listeners for a given namespace
     - parameter namespace: namespace to listen to
     */
    private func triggerListening(to namespace: MongoNamespace) {
        syncLock.writeLock()
        defer { syncLock.unlock() }
        do {
            guard let nsConfig = self.syncConfig[namespace] else {
                return
            }

            guard nsConfig.count > 0,
                nsConfig.isConfigured else {
                    // TODO STITCH-2217: removeNamespace
                    return
            }

            // TODO STITCH-2217: addNamespace, stop, start
        } catch {
            log.e("t='\(logicalT)': triggerListeningToNamespace ns=\(namespace) exception: \(error)")
        }
    }

    /**
     * Returns the local collection representing the given namespace.
     *
     * @param namespace   the namespace referring to the local collection.
     * @param resultClass the {@link Class} that represents documents in the collection.
     * @param <T>         the type documents in the collection.
     * @return the local collection representing the given namespace.
     */
    private func localCollection<T: Codable>(for namespace: MongoNamespace,
                                             withType type: T.Type = T.self) throws -> MongoCollection<T> {
        return try localClient.db(DataSynchronizer.localUserDBName(withInstanceKey: instanceKey,
                                                                   for: namespace))
            .collection(namespace.collectionName, withType: type)
    }

    internal static func localConfigDBName(withInstanceKey instanceKey: String) -> String {
        return "sync_config_\(instanceKey)"
    }
    
    internal static func localUserDBName(withInstanceKey instanceKey: String,
                                         for namespace: MongoNamespace) -> String {
        return "sync_user_\(instanceKey)_\(namespace.databaseName)"
    }
}
