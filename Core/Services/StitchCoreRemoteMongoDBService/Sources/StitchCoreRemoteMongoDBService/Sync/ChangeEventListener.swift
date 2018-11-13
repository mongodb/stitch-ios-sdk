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

    init<U: ChangeEventListener>(_ changeEventListener: U) {
        self._onEvent = { documentId, event in
            changeEventListener.onEvent(documentId: documentId,
                                        event: ChangeEvent<U.DocumentT>.transform(changeEvent: event))
        }
    }

    public func onEvent(documentId: BSONValue, event: ChangeEvent<Document>) {
        self._onEvent(documentId, event)
    }
}
