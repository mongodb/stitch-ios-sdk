import MongoSwift

/**
 ErrorListener receives non-network related errors that occur.
 */
public protocol ErrorListener {
    /**
     Called when an error happens for the given document id.

     - parameter error: the error.
     - parameter documentId: the _id of the document related to the error.
     */
    func on(error: DataSynchronizerError, forDocumentId documentId: BSONValue?)
}

internal class BlockErrorDelegate: ErrorListener {
    private let onErrorBlock: (_ error: DataSynchronizerError, _ documentId: BSONValue?) -> Void
    public init(_ onErrorBlock: @escaping (_ error: DataSynchronizerError, _ documentId: BSONValue?) -> Void) {
        self.onErrorBlock = onErrorBlock
    }

    public func on(error: DataSynchronizerError, forDocumentId documentId: BSONValue?) {
        self.onErrorBlock(error, documentId)
    }
}

/**
 FatalErrorListener receives low level errors unrelated to the sync process.
*/
internal protocol FatalErrorListener: class {
    /**
     Called when a fatal error occurs.

     - parameter error: the error.
     - parameter documentId: the _id of the document related to the error.
     - parameter namespace: the namespace the error may have occured in
     */
    func on(error: Error, forDocumentId documentId: BSONValue?, in namespace: MongoNamespace?)
}
