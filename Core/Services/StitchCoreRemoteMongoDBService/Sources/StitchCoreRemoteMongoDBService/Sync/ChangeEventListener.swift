import Foundation
import MongoSwift

/**
 * ChangeEventListener receives change event notifications.
 * @param <DocumentT> the type of class represented by the document in the change event.
 */
public protocol ChangeEventListener {
    associatedtype DocumentT: Codable
    /**
     * Called when a change event happens for the given document id.
     *
     * @param documentId the _id of the document related to the event.
     * @param event the change event.
     */
    func onEvent(documentId: BSONValue, event: ChangeEvent<DocumentT>)
}

final class AnyChangeEventListener: ChangeEventListener {
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
