import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * `Sync` is a set of synchronization-related operations for a `RemoteMongoCollection`.
 *
 * Using Sync, you can synchronize local and remote data.
 *
 * - SeeAlso:
 * [Build a Mobile App with Sync](https://docs.mongodb.com/stitch/mongodb/mobile/build-sync/),
 * RemoteMongoCollection
 */
public class Sync<DocumentT: Codable> {
    internal let proxy: CoreSync<DocumentT>
    internal let queue = DispatchQueue.init(label: "sync", qos: .userInitiated)

    internal init(proxy: CoreSync<DocumentT>) {
        self.proxy = proxy
    }

    /**
     Set the conflict resolver and and change event listener on this collection.
     - parameter conflictHandler: the conflict resolver to invoke when a conflict happens between local
     and remote events.
     - parameter changeEventDelegate: the event listener to invoke when a change event happens for the
     document.
     - parameter errorListener: the error listener to invoke when an irrecoverable error occurs
     - parameter completionHandler: the handler to execute when configuration is complete
     */
    public func configure(
        conflictHandler: @escaping (
        _ documentId: BSONValue,
        _ localEvent: ChangeEvent<DocumentT>,
        _ remoteEvent: ChangeEvent<DocumentT>)  throws -> DocumentT?,
        changeEventDelegate: ((_ documentId: BSONValue, _ event: ChangeEvent<DocumentT>) -> Void)? = nil,
        errorListener:  ((_ error: DataSynchronizerError, _ documentId: BSONValue?) -> Void)? = nil,
        _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        queue.async {
            completionHandler(.success(result: self.proxy.configure(conflictHandler: conflictHandler,
                                                                    changeEventDelegate: changeEventDelegate,
                                                                    errorListener: errorListener)))
        }
    }

    /**
     Set the conflict resolver and and change event listener on this collection.
     - parameter conflictHandler: the conflict resolver to invoke when a conflict happens between local
     and remote events.
     - parameter changeEventDelegate: the event listener to invoke when a change event happens for the
     document.
     - parameter errorListener: the error listener to invoke when an irrecoverable error occurs
     - parameter completionHandler: the handler to execute when configuration is complete
     */
    public func configure<CH: ConflictHandler, CED: ChangeEventDelegate>(
        conflictHandler: CH,
        changeEventDelegate: CED? = nil,
        errorListener: ErrorListener? = nil,
        _ completionHandler: @escaping (StitchResult<Void>) -> Void
    ) where CH.DocumentT == DocumentT, CED.DocumentT == DocumentT {
        queue.async {
            completionHandler(.success(result: self.proxy.configure(conflictHandler: conflictHandler,
                                                                    changeEventDelegate: changeEventDelegate,
                                                                    errorListener: errorListener)))
        }
    }

    /**
     Requests that the given document _ids be synchronized.
     - parameter ids: the document _ids to synchronize.
     - parameter completionHandler: the handler to execute when the provided ids are marked as synced. The documents
                                    will not necessarily exist in the local collection yet, but will get synced
                                    down in the next background sync pass
     */
    public func sync(ids: [BSONValue], _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.sync(ids: ids)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .syncInitializationError(withError: error))))
            }
        }
    }

    /**
     Stops synchronizing the given document _ids. Any uncommitted writes will be lost.
     - parameter ids: the _ids of the documents to desynchronize.
     - parameter completionHandler: the handler to execute when the provided ids are no longer marked as synced. The
                                    documents will be deleted from the local collection, but not the remote collection.
     */
    public func desync(ids: [BSONValue], _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        queue.async {
            do {
                completionHandler(
                    .success(result: try self.proxy.desync(ids: ids)))
            } catch {
                completionHandler(
                    .failure(error: .clientError(withClientErrorCode: .syncInitializationError(withError: error))))
            }
        }
    }

    /**
     Returns the set of synchronized document ids in a namespace.
     Remove custom AnyBSONValue after: https://jira.mongodb.org/browse/SWIFT-255
     - returns: the set of synchronized document ids in a namespace.
     */
    public func syncedIds(_ completionHandler: @escaping (StitchResult<Set<AnyBSONValue>>) -> Void) {
        queue.async {
            completionHandler(.success(result: self.proxy.syncedIds))
        }
    }

    /**
     Return the set of synchronized document _ids in a namespace
     that have been paused due to an irrecoverable error.

     - returns: the set of paused document _ids in a namespace
     */
    public func pausedIds(_ completionHandler: @escaping (StitchResult<Set<AnyBSONValue>>) -> Void) {
        queue.async {
            completionHandler(.success(result: self.proxy.pausedIds))
        }
    }

    /**
     A document that is paused no longer has remote updates applied to it.
     Any local updates to this document cause it to be resumed. An example of pausing a document
     is when a conflict is being resolved for that document and the handler throws an exception.

     - parameter documentId: the id of the document to resume syncing
     - returns: true if successfully resumed, false if the document
     could not be found or there was an error resuming
     */
    public func resumeSync(
        forDocumentId documentId: BSONValue,
        _ completionHandler: @escaping (StitchResult<Bool>) -> Void) {
        queue.async {
            completionHandler(.success(result: self.proxy.resumeSync(forDocumentId: documentId)))
        }
    }
}
