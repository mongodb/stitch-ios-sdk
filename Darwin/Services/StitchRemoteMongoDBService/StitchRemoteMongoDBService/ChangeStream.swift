import Foundation
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

/**
 * A MongoDB Change Stream session
 */
public protocol ChangeStreamSession {
    var delegate: ChangeStreamDelegate? { get set }
    func close()
}

internal class ChangeStreamSessionImpl<DocumentT: Codable>: SSEStreamDelegate, ChangeStreamSession {
    internal var rawStream: RawSSEStream?

    /**
     * The delegate for this `ChangeStreamSession`. This is the class that will react to incoming events. A delegate is
     * set at the time the `watch` function is called, but a new delegate may also be set here.

     * - warning the delegate is held by the change stream as a weak reference. If the delegate becomes
     *           deallocated, the stream will automatically close the next time an event is received. If you are
     *           setting a new delegate, make sure you do so before the previous delegate is deallocated.
     */
    public weak var delegate: ChangeStreamDelegate?

    internal init(publicDelegate: ChangeStreamDelegate) {
        self.delegate = publicDelegate
    }

    override final public func on(newEvent event: RawSSE) {
        guard let delegate = delegate else {
            self.close()
            return
        }

        do {
            let changeEvent: ChangeEvent<DocumentT>? = try event.decodeStitchSSE()
            guard let concreteChangeEvent = changeEvent else {
                self.on(error: StitchError.requestError(withMessage: "invalid event received from stream",
                                                        withRequestErrorCode: .decodingError))
                return
            }

            // Dispatch change event to user stream
            delegate.didReceive(event: concreteChangeEvent)

        } catch let err {
            self.on(error: StitchError.requestError(withError: err, withRequestErrorCode: .decodingError))
        }
    }

    override final public func on(error: Error) {
        guard let delegate = delegate else {
            self.close()
            return
        }

        // Dispatch error to user stream
        delegate.didReceive(streamError: error)
    }

    override final public func on(stateChangedFor state: SSEStreamState) {
        guard let delegate = delegate else {
            self.close()
            return
        }

        switch state {
        case .opening:
            break
        case .open:
            delegate.didOpen()
        case .closing:
            break
        case .closed:
            delegate.didClose()
        }
    }

    public func close() {
        guard let rawStream = rawStream else {
            return
        }
        switch rawStream.state {
        case SSEStreamState.closed, SSEStreamState.closing:
            // remove the reference to the underlying stream so the FoundationDataDelegate in the
            // FoundationHTTPSSEStream is deallocated
            self.rawStream = nil
            return
        default:
            rawStream.close()
        }
    }
}
