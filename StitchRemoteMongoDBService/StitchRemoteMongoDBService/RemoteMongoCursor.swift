import Foundation
import StitchCore
import StitchCoreRemoteMongoDBService

/**
 * A cursor of documents which can be traversed asynchronously. A `RemoteMongoCursor` can be the result of a `find` or
 * `aggregate` operation.
 */
public class RemoteMongoCursor<T: Codable> {
    private let dispatcher: OperationDispatcher
    private let proxy: CoreRemoteMongoCursor<T>
    
    internal init(withCursor cursor: CoreRemoteMongoCursor<T>,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = cursor
        self.dispatcher = dispatcher
    }
    
    /**
     * Retrieves the next document in this cursor, potentially fetching from the server.
     *
     * - parameters:
     *   - completionHandler: The completion handler to call when the document is retrieved or if the operation fails.
     *                        This handler is executed on a non-main global `DispatchQueue`.
     *   - result: An optional `T` indicating the next document in the cursor. Will be singly `nil` if there are no
     *             more documents in the cursor, or doubly `nil` if the operation failed.
     *   - error: An error object that indicates why the operation failed, or `nil` if the operation was successful.
     */
    public func next(_ completionHandler: @escaping (T??, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
           return self.proxy.next()
        }
    }
}
