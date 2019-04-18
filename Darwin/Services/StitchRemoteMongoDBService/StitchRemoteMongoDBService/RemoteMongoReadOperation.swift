import Foundation
import MongoSwift
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * `RemoteMongoReadOperation` represents a `find` or `aggregate` operation 
 * on a `RemoteMongoCollection`.
 * 
 * The methods in this class execute the operation and retrieve the results.
 *
 * - SeeAlso:
 * `RemoteMongoCollection`
 */
public class RemoteMongoReadOperation<T: Codable> {
    private let proxy: CoreRemoteMongoReadOperation<T>
    private let dispatcher: OperationDispatcher

    internal init(withOperations operations: CoreRemoteMongoReadOperation<T>,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = operations
        self.dispatcher = dispatcher
    }

    /**
     * Executes the operation and returns the first document in the result.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain an optional `T` indicating the first document in the
     *                        result. the document will be `nil` if the result was empty.
     */
    public func first(_ completionHandler: @escaping (StitchResult<T?>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.first()
        }
    }

    /**
     * Executes the operation and returns the result as an array.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the documents in the result as an array.
     */
    public func toArray(_ completionHandler: @escaping (StitchResult<[T]>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.toArray()
        }
    }

    /**
     * Executes the operation and returns the result as an array. Deprecated in favor of `toArray(completionHandler:)`.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain the documents in the result as an array.
     */
    @available(*, deprecated, message: "use toArray instead")
    public func asArray(_ completionHandler: @escaping (StitchResult<[T]>) -> Void) {
        self.toArray(completionHandler)
    }

    /**
     * Executes the operation and returns a `RemoteMongoCursor` to its resulting documents.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                        successful, the result will contain an asynchronously iterating cursor to the documents
     *                        in the result.
     */
    public func iterator(_ completionHandler: @escaping (StitchResult<RemoteMongoCursor<T>>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try RemoteMongoCursor.init(withCursor: self.proxy.iterator(), withDispatcher: self.dispatcher)
        }
    }
}
