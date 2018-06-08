import Foundation
import MongoSwift
import StitchCore_iOS
import StitchCoreServicesMongoDbRemote

/**
 * Represents a `find` or `aggregate` operation against a MongoDB collection. Use the methods in this class to execute
 * the operation and retrieve the results.
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
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: An optional `T` indicating the first document in the result. Will be singly `nil` if the result was
     *             empty, or doubly `nil` if the operation failed.
     *   - error: An error object that indicates why the operation failed, or `nil` if the operation was successful.
     */
    public func first(_ completionHandler: @escaping (_ result: T??, _ error: Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.first()
        }
    }
    
    /**
     * Executes the operation and returns the result as an array.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: The documents in the result as an array. Will be `nil` if the operation failed.
     *   - error: An error object that indicates why the operation failed, or `nil` if the operation was successful.
     */
    public func asArray(_ completionHandler: @escaping (_ result: [T]?, _ error: Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.asArray()
        }
    }
    
    /**
     * Executes the operation and returns a cursor to its resulting documents.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the operation is completed or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: An iterating cursor to the documents in the result. Will be `nil` if the operation failed.
     *   - error: An error object that indicates why the operation failed, or `nil` if the operation was successful.
     */
    public func iterator(_ completionHandler: @escaping (RemoteMongoCursor<T>?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try RemoteMongoCursor.init(withCursor: self.proxy.iterator(), withDispatcher: self.dispatcher)
        }
    }
}
