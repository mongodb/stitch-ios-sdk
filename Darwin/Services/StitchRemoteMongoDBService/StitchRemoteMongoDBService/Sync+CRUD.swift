import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * A set of CRUD operations for a synchronized collection.
 */
public extension Sync {
    /**
     Counts the number of documents in the collection that have been synchronized with the remote.

     - returns: the number of documents in the collection
     */
    func count(_ completionHandler: @escaping (StitchResult<Int>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.count()))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
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
               options: SyncCountOptions?,
               _ completionHandler: @escaping (StitchResult<Int>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.count(filter: filter,
                                                          options: options)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
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
                    .success(result: try self.proxy.find()))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
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
        options: SyncFindOptions? = nil,
        _ completionHandler: @escaping (StitchResult<MongoCursor<DocumentT>>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.find(filter: filter, options: options)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
            }
        }
    }

    /**
     Finds a document in the collection that has been synchronized with the remote.

     - parameter filter: the query filter for this find op
     - parameter options: the options for this find op
     - parameter completionHandler: the callback for the find result
     - returns: the document or nil if no such document existss
     */
    func findOne(
        filter: Document? = nil,
        options: SyncFindOptions? = nil,
        _ completionHandler: @escaping (StitchResult<DocumentT?>) -> Void) {
        queue.async {
            do {
                let newFilter: Document!
                if let filter = filter { newFilter = filter} else {newFilter = Document.init()}
                completionHandler(
                    .success(result: try self.proxy.findOne(filter: newFilter, options: options)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
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
                    .success(result: try self.proxy.aggregate(pipeline: pipeline, options: options)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))))
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
                   _ completionHandler: @escaping (StitchResult<SyncInsertOneResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.insertOne(document: document)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
            }
        }
    }

    /**
     Inserts one or more documents. Syncs the newly inserted documents against the remote.

     - parameter documents: the documents to insert
     - returns: the result of the insert many operation
     */
    func insertMany(documents: [DocumentT],
                    _ completionHandler: @escaping (StitchResult<SyncInsertManyResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.insertMany(documents: documents)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
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
    func deleteOne(filter: Document,
                   _ completionHandler: @escaping (StitchResult<SyncDeleteResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.deleteOne(filter: filter)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
            }
        }
    }

    /**
     Removes all documents from the collection that have been synchronized with the remote
     that match the given query filter.  If no documents match, the collection is not modified.

     - parameter filter: the query filter to apply the the delete operation
     - returns: the result of the remove many operation
     */
    func deleteMany(filter: Document,
                    _ completionHandler: @escaping (StitchResult<SyncDeleteResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(result: try self.proxy.deleteMany(filter: filter)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
            }
        }
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
                   options: SyncUpdateOptions?,
                   _ completionHandler: @escaping (StitchResult<SyncUpdateResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(
                    result: try self.proxy.updateOne(filter: filter,
                                                     update: update,
                                                     options: options)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
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
                    options: SyncUpdateOptions?,
                    _ completionHandler: @escaping (StitchResult<SyncUpdateResult?>) -> Void) {
        queue.async {
            do {
                completionHandler(.success(
                    result: try self.proxy.updateMany(filter: filter,
                                                      update: update,
                                                      options: options)))
            } catch {
                completionHandler(.failure(
                    error: .clientError(withClientErrorCode: .mongoDriverError(withError: error))
                    ))
            }
        }
    }
}
