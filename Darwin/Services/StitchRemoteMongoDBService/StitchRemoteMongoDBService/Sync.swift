import Foundation
import StitchCoreRemoteMongoDBService
import MongoSwift
import StitchCore

public class Sync<DocumentT: Codable> {
    private let proxy: CoreSync<DocumentT>
    private let queue = DispatchQueue.init(label: "sync", qos: .userInitiated)

    internal init(proxy: CoreSync<DocumentT>) {
        self.proxy = proxy
    }

    /**
     Set the conflict resolver and and change event listener on this collection.
     - parameter conflictHandler: the conflict resolver to invoke when a conflict happens between local
     and remote events.
     - parameter changeEventListener: the event listener to invoke when a change event happens for the
     document.
     - parameter errorListener: the error listener to invoke when an irrecoverable error occurs
     */
    func configure<CH: ConflictHandler, CEL: ChangeEventListener>(
        conflictHandler: CH,
        changeEventListener: CEL,
        errorListener: ErrorListener) where CH.DocumentT == DocumentT, CEL.DocumentT == DocumentT {
        self.proxy.configure(conflictHandler: conflictHandler,
                             changeEventListener: changeEventListener,
                             errorListener: errorListener)
    }

    /**
     Requests that the given document _ids be synchronized.
     - parameter ids: the document _ids to synchronize.
     */
    func sync(ids: [BSONValue]) {
        self.proxy.sync(ids: ids)
    }

    /**
     Stops synchronizing the given document _ids. Any uncommitted writes will be lost.
     - parameter ids: the _ids of the documents to desynchronize.
     */
    func desync(ids: [BSONValue]) {
        self.proxy.desync(ids: ids)
    }

    /**
     Returns the set of synchronized document ids in a namespace.
     TODO Remove custom HashableBSONValue after: https://jira.mongodb.org/browse/SWIFT-255
     - returns: the set of synchronized document ids in a namespace.
     */
    var syncedIds: Set<HashableBSONValue> {
        return self.proxy.syncedIds
    }

    /**
     Return the set of synchronized document _ids in a namespace
     that have been paused due to an irrecoverable error.

     - returns: the set of paused document _ids in a namespace
     */
    var pausedIds: Set<HashableBSONValue> {
        return self.proxy.pausedIds
    }

    /**
     A document that is paused no longer has remote updates applied to it.
     Any local updates to this document cause it to be resumed. An example of pausing a document
     is when a conflict is being resolved for that document and the handler throws an exception.

     - parameter documentId: the id of the document to resume syncing
     - returns: true if successfully resumed, false if the document
     could not be found or there was an error resuming
     */
    func resumeSync(forDocumentId documentId: BSONValue) -> Bool {
        return self.proxy.resumeSync(forDocumentId: documentId)
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote.

     - returns: the number of documents in the collection
     */
    func count(_ completionHandler: @escaping (StitchResult<Int>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    StitchResult.success(result: try self.proxy.count()))
            } catch {
                completionHandler(
                    StitchResult.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Counts the number of documents in the collection that have been synchronized with the remote
     according to the given options.

     - parameter filter:  the query filter
     - parameter options: the options describing the count
     - parameter completionHandler: the callback for the count result
     - returns: the number of documents in the collection
     */
    func count(filter: Document,
               options: CountOptions?,
               _ completionHandler: @escaping (StitchResult<Int>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    StitchResult.success(result: try self.proxy.count(filter: filter,
                                                                      options: options)))
            } catch {
                completionHandler(
                    StitchResult.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - parameter completionHandler: the callback for the find result
     - returns: the find iterable interface
     */
    func find(_ completionHandler: @escaping (StitchResult<MongoCursor<DocumentT>>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    StitchResult.success(result: try self.proxy.find()))
            } catch {
                completionHandler(
                    StitchResult.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Finds all documents in the collection that have been synchronized with the remote.

     - parameter filter: the query filter for this find op
     - parameter options: the options for this find op
     - parameter completionHandler: the callback for the find result
     - returns: the find iterable interface
     */
    func find(
        filter: Document,
        options: FindOptions?,
        _ completionHandler: @escaping (StitchResult<MongoCursor<DocumentT>>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.find(filter: filter, options: options)))
            } catch {
                completionHandler(
                    .failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Aggregates documents that have been synchronized with the remote
     according to the specified aggregation pipeline.

     - parameter pipeline: the aggregation pipeline
     - parameter options: the options for this aggregate op
     - returns: an iterable containing the result of the aggregation operation
     */
    func aggregate(pipeline: [Document],
                   options: AggregateOptions?,
                   _ completionHandler: @escaping (StitchResult<MongoCursor<Document>>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    StitchResult.success(result: try self.proxy.aggregate(pipeline: pipeline, options: options)))
            } catch {
                completionHandler(
                    StitchResult.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }



    /**
     Inserts the provided document. If the document is missing an identifier, the client should
     generate one. Syncs the newly inserted document against the remote.

     - parameter document: the document to insert
     - returns: the result of the insert one operation
     */
    func insertOne(document: DocumentT,
                   _ completionHandler: @escaping (StitchResult<InsertOneResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.insertOne(document: document)))
            } catch {
                completionHandler(.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Inserts one or more documents. Syncs the newly inserted documents against the remote.

     - parameter documents: the documents to insert
     - returns: the result of the insert many operation
     */
    func insertMany(documents: [DocumentT],
                    _ completionHandler: @escaping (StitchResult<InsertManyResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.insertMany(documents: documents)))
            } catch {
                completionHandler(.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Removes at most one document from the collection that has been synchronized with the remote
     that matches the given filter.  If no documents match, the collection is not
     modified.

     - parameter filter: the query filter to apply the the delete operation
     - returns: the result of the remove one operation
     */
    func deleteOne(filter: Document) -> DeleteResult? {
        return self.proxy.deleteOne(filter: filter)
    }

    /**
     Removes all documents from the collection that have been synchronized with the remote
     that match the given query filter.  If no documents match, the collection is not modified.

     - parameter filter: the query filter to apply the the delete operation
     - returns: the result of the remove many operation
     */
    func deleteMany(filter: Document) -> DeleteResult? {
        return self.proxy.deleteMany(filter: filter)
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
    func updateOne(filter: Document,
                   update: Document,
                   options: UpdateOptions?,
                   _ completionHandler: @escaping (StitchResult<UpdateResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(
                    result: try self.proxy.updateOne(filter: filter,
                                                     update: update,
                                                     options: options)))
            } catch {
                completionHandler(.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
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
    func updateMany(filter: Document,
                    update: Document,
                    options: UpdateOptions?,
                    _ completionHandler: @escaping (StitchResult<UpdateResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(
                    result: try self.proxy.updateMany(filter: filter,
                                                      update: update,
                                                      options: options)))
            } catch {
                completionHandler(.failure(error: StitchError.clientError(withClientErrorCode: StitchClientErrorCode.mongoDriverError(withError: error))))
            }
        }
    }
}
