import MongoSwift

/**
 ChangeEventDelegate receives change event notifications.
 */
public protocol ChangeEventDelegate: class {
    /// The type of class represented by the document in the change event.
    associatedtype DocumentT: Codable
    /**
     Called when a change event happens for the given document id.

     - parameter documentId: the _id of the document related to the event.
     - parameter event: the change event.
     */
    func onEvent(documentId: BSONValue, event: ChangeEvent<DocumentT>)
}

internal class BlockChangeEventDelegate<T: Codable>: ChangeEventDelegate {
    public typealias DocumentT = T

    private let onEventBlock: (_ documentId: BSONValue, _ event: ChangeEvent<DocumentT>) -> Void
    public init(_ onEventBlock:
        @escaping (_ documentId: BSONValue, _ event: ChangeEvent<DocumentT>) -> Void) {
        self.onEventBlock = onEventBlock
    }

    public func onEvent(documentId: BSONValue, event: ChangeEvent<T>) {
        self.onEventBlock(documentId, event)
    }
}

internal final class AnyChangeEventDelegate: ChangeEventDelegate {
    private let _onEvent: (BSONValue, ChangeEvent<Document>) -> Void

    init<U: ChangeEventDelegate>(_ changeEventDelegate: U, errorListener: FatalErrorListener?) {
        self._onEvent = { documentId, event in
            do {
                changeEventDelegate.onEvent(documentId: documentId,
                                            event: try ChangeEvents.transform(changeEvent: event))
            } catch {
                errorListener?.on(error: error, forDocumentId: documentId, in: event.ns)
            }
        }
    }

    public func onEvent(documentId: BSONValue, event: ChangeEvent<Document>) {
        self._onEvent(documentId, event)
    }
}
