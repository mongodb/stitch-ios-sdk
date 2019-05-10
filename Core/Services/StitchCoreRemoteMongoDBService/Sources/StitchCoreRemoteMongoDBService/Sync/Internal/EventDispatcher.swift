import MongoSwift
import StitchCoreSDK

class EventDispatcher {
    /// RW lock for the listeners
    private let listenersLock: ReadWriteLock
    /// Dispatch queue to send events
    private let eventDispatchQueue: DispatchQueue
    /// Logger to emit error message if needed
    private let logger: Log

    init(_ eventDispatchQueue: DispatchQueue, _ logger: Log, _ service: CoreStitchServiceClient) {
        self.eventDispatchQueue = eventDispatchQueue
        self.listenersLock = ReadWriteLock(label: "listeners_\(service.serviceName ?? "mongodb-atlas")")
        self.logger = logger
    }

    /**
     Emits a change event for the given document id.

     - parameter nsConfig:   the namespace of the document that has a change event for it.
     - parameter event:      the change event.
     */
    public func emitEvent(nsConfig: NamespaceSynchronization, event: ChangeEvent<Document>) {
        guard let documentId = event.documentKey["_id"] else {
            logger.e("Could not log event for namespace \(nsConfig.namespace), missing document ID: "
                + "\(event.documentKey.canonicalExtendedJSON)")
            return
        }

        listenersLock.write {
            eventDispatchQueue.async {
                nsConfig.changeEventDelegate?.onEvent(documentId: documentId, event: event)
            }
        }
    }
}
