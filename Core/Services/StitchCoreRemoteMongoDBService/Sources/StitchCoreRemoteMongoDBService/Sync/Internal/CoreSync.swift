import Foundation
import MongoSwift

/**
 A set of synchronization related operations for a collection.
 */
public final class CoreSync<DocumentT: Codable> {
    /// The namespace of the collection.
    internal let namespace: MongoNamespace
    /// The dataSynchronizer from the RemoteCollection.
    internal let dataSynchronizer: DataSynchronizer
    /// Lazily initialized encoder for T
    private lazy var encoder = BSONEncoder()

    internal init(namespace: MongoNamespace,
                  dataSynchronizer: DataSynchronizer) {
        self.namespace = namespace
        self.dataSynchronizer = dataSynchronizer
    }

    public func configure(
        conflictHandler: @escaping (
        _ documentId: BSONValue,
        _ localEvent: ChangeEvent<DocumentT>,
        _ remoteEvent: ChangeEvent<DocumentT>) throws -> DocumentT?,
        changeEventDelegate: ((_ documentId: BSONValue, _ event: ChangeEvent<DocumentT>) -> Void)?,
        errorListener: ((_ error: DataSynchronizerError, _ documentId: BSONValue?) -> Void)?) {
        self.dataSynchronizer.configure(
            namespace: namespace,
            conflictHandler: BlockConflictHandler(conflictHandler),
            changeEventDelegate: changeEventDelegate != nil ? BlockChangeEventDelegate(changeEventDelegate!) : nil,
            errorListener: errorListener != nil ? BlockErrorDelegate(errorListener!) : nil)
    }

    /**
     Set the conflict resolver and and change event listener on this collection.
     - parameter conflictHandler: the conflict resolver to invoke when a conflict happens between local
     and remote events.
     - parameter changeEventDelegate: the event listener to invoke when a change event happens for the
     document.
     - parameter errorListener: the error listener to invoke when an irrecoverable error occurs
     */
    public func configure<CH: ConflictHandler, CED: ChangeEventDelegate>(
        conflictHandler: CH,
        changeEventDelegate: CED?,
        errorListener: ErrorListener?) where CH.DocumentT == DocumentT, CED.DocumentT == DocumentT {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: conflictHandler,
                                   changeEventDelegate: changeEventDelegate,
                                   errorListener: errorListener)
    }

    /**
     Requests that the given document _ids be synchronized.
     - parameter ids: the document _ids to synchronize.
     */
    public func sync(ids: [BSONValue]) throws {
        try self.dataSynchronizer.sync(ids: ids, in: namespace)
    }

    /**
     Stops synchronizing the given document _ids. Any uncommitted writes will be lost.
     - parameter ids: the _ids of the documents to desynchronize.
     */
    public func desync(ids: [BSONValue]) throws {
        try self.dataSynchronizer.desync(ids: ids, in: namespace)
    }

    /**
     Returns the set of synchronized document ids in a namespace.
     - returns: the set of synchronized document ids in a namespace.
     */
    public var syncedIds: Set<AnyBSONValue> {
        return self.dataSynchronizer.syncedIds(in: namespace)
    }

    /**
     Return the set of synchronized document _ids in a namespace
     that have been paused due to an irrecoverable error.

     - returns: the set of paused document _ids in a namespace
     */
    public var pausedIds: Set<AnyBSONValue> {
        return self.dataSynchronizer.pausedIds(in: namespace)
    }

    /**
     A document that is paused no longer has remote updates applied to it.
     Any local updates to this document cause it to be resumed. An example of pausing a document
     is when a conflict is being resolved for that document and the handler throws an exception.

     - parameter documentId: the id of the document to resume syncing
     - returns: true if successfully resumed, false if the document
     could not be found or there was an error resuming
     */
    public func resumeSync(forDocumentId documentId: BSONValue) -> Bool {
        return self.dataSynchronizer.resumeSync(for: documentId,
                                                in: namespace)
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote.

     - returns: the number of documents in the collection
     */
    public func count() throws -> Int {
        return try self.dataSynchronizer.count(in: namespace)
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote
     according to the given options.

     - parameter filter:  the query filter
     - parameter options: the options describing the count
     - returns: the number of documents in the collection
     */
    public func count(filter: Document, options: SyncCountOptions? = nil) throws -> Int {
        return try self.dataSynchronizer.count(filter: filter,
                                               options: options,
                                               in: namespace)
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - returns: the find iterable interface
     */
    public func find() throws -> MongoCursor<DocumentT> {
        return try self.dataSynchronizer.find(in: namespace)
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - parameter filter: the query filter for this find op
     - parameter options: the options for this findo p
     - returns: the find iterable interface
     */
    public func find(filter: Document, options: SyncFindOptions? = nil) throws -> MongoCursor<DocumentT> {
        return try self.dataSynchronizer.find(filter: filter,
                                              options: options,
                                              in: namespace)
    }

    /**
     Returns one document from a collection that has been synchronized with the
     remote that matches the provided filter. If multiple documents satisfy the
     query, this method returns the first document according to the query's sort
     order or natural order.

     - parameter filter: the query filter for this find op
     - parameter options: the options for this find op
     - returns:  The resulting `Document` or nil if no such document exists
     */
    public func findOne(filter: Document, options: SyncFindOptions? = nil) throws -> DocumentT? {
        return try self.dataSynchronizer.findOne(filter: filter, options: options, in: namespace)
    }

    /**
     Aggregates documents that have been synchronized with the remote
     according to the specified aggregation pipeline.

     - parameter pipeline: the aggregation pipeline
     - parameter options: the options for this aggregate op
     - returns: an iterable containing the result of the aggregation operation
     */
    public func aggregate(pipeline: [Document],
                          options: AggregateOptions? = nil) throws -> MongoCursor<Document> {
        return try self.dataSynchronizer.aggregate(pipeline: pipeline,
                                                   options: options,
                                                   in: namespace)
    }

    /**
     Inserts the provided document. If the document is missing an identifier, the client should
     generate one. Syncs the newly inserted document against the remote.

     - parameter document: the document to insert
     - returns: the result of the insert one operation
     */
    public func insertOne(document: DocumentT) throws -> SyncInsertOneResult? {
        return try self.dataSynchronizer.insertOne(document: encoder.encode(document),
                                                   in: namespace)
    }

    /**
     Inserts one or more documents. Syncs the newly inserted documents against the remote.

     - parameter documents: the documents to insert
     - returns: the result of the insert many operation
     */
    public func insertMany(documents: [DocumentT]) throws -> SyncInsertManyResult? {
        return try self.dataSynchronizer.insertMany(documents: try documents.map { try encoder.encode($0) },
                                                    in: namespace)
    }

    /**
     Removes at most one document from the collection that has been synchronized with the remote
     that matches the given filter.  If no documents match, the collection is not
     modified.

     - parameter filter: the query filter to apply the the delete operation
     - returns: the result of the remove one operation
     */
    public func deleteOne(filter: Document) throws -> SyncDeleteResult? {
        return try self.dataSynchronizer.deleteOne(filter: filter,
                                                   options: nil,
                                                   in: namespace)
    }

    /**
     Removes all documents from the collection that have been synchronized with the remote
     that match the given query filter.  If no documents match, the collection is not modified.

     - parameter filter: the query filter to apply the the delete operation
     - returns: the result of the remove many operation
     */
    public func deleteMany(filter: Document) throws -> SyncDeleteResult? {
        return try self.dataSynchronizer.deleteMany(filter: filter,
                                                    options: nil,
                                                    in: namespace)
    }

    /**
     Update a single document in the collection that have been synchronized with the remote
     according to the specified arguments. If the update results in an upsert,
     the newly upserted document will automatically become synchronized.

     - parameter filter: a document describing the query filter, which may not be null.
     - parameter update: a document describing the update, which may not be null. The update to
     apply must include only update operators.
     - returns: the result of the update one operation
     */
    public func updateOne(filter: Document,
                          update: Document,
                          options: SyncUpdateOptions?) throws -> SyncUpdateResult? {
        return try self.dataSynchronizer.updateOne(filter: filter,
                                                   update: update,
                                                   options: options,
                                                   in: namespace)
    }

    /**
     Update all documents in the collection that have been synchronized with the remote
     according to the specified arguments. If the update results in an upsert,
     the newly upserted document will automatically become synchronized.

     - parameter filter: a document describing the query filter, which may not be null.
     - parameter update: a document describing the update, which may not be null. The update to
     apply must include only update operators.
     - parameter updateOptions: the options to apply to the update operation
     - returns: the result of the update many operation
     */
    public func updateMany(filter: Document,
                           update: Document,
                           options: SyncUpdateOptions?) throws -> SyncUpdateResult? {
        return try self.dataSynchronizer.updateMany(filter: filter,
                                                    update: update,
                                                    options: options,
                                                    in: namespace)
    }
}
