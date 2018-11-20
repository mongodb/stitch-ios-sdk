import MongoSwift

/**
 ChangeEventListener receives change event notifications.
 */
public protocol ChangeEventListener {
    /// The type of class represented by the document in the change event.
    associatedtype DocumentT: Codable
    /**
     Called when a change event happens for the given document id.

     - parameter documentId: the _id of the document related to the event.
     - parameter event: the change event.
     */
    func onEvent(documentId: BSONValue, event: ChangeEvent<DocumentT>)
}

internal final class AnyChangeEventListener: ChangeEventListener {
    private let _onEvent: (BSONValue, ChangeEvent<Document>) -> Void

    init<U: ChangeEventListener>(_ changeEventListener: U, errorListener: FatalErrorListener?) {
        self._onEvent = { documentId, event in
            do {
                changeEventListener.onEvent(documentId: documentId,
                                            event: try ChangeEvent<U.DocumentT>.transform(changeEvent: event))
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId, in: event.ns)
            }
        }
    }

    public func onEvent(documentId: BSONValue, event: ChangeEvent<Document>) {
        self._onEvent(documentId, event)
    }
}
