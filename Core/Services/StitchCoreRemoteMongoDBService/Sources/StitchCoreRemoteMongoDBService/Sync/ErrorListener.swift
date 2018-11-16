import MongoSwift

/**
 ErrorListener receives non-network related errors that occur.
 */
protocol ErrorListener: class {
    /**
     Called when an error happens for the given document id.

     - parameter error: the error.
     - parameter documentId: the _id of the document related to the error.
     */
    func on(error: Error, forDocumentId documentId: BSONValue?)
}
