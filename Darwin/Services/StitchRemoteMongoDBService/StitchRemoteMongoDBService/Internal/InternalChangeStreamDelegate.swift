import Foundation
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

/**
 * Internal class which serves as an intermediary between an internal RawSSEStream and a change stream as exposed
 * by the remote MongoDB service.
 */
internal class InternalChangeStreamDelegate<PublicDelegateT: ChangeStreamDelegate>: SSEStreamDelegate {
    public weak var delegate: PublicDelegateT?
    internal var rawStream: RawSSEStream?

    public init(delegate: PublicDelegateT) {
        self.delegate = delegate
    }

    public func close() {
        guard let rawStream = rawStream else {
            return
        }
        switch rawStream.state {
        case SSEStreamState.closed, SSEStreamState.closing:
            break
        default:
            rawStream.close()
        }

        // remove the reference to the underlying stream so the FoundationDataDelegate in the
        // FoundationHTTPSSEStream is deallocated
        self.rawStream = nil
    }

    override final public func on(newEvent event: RawSSE) {
        guard let delegate = delegate else {
            self.close()
            return
        }

        do {
            let changeEvent: ChangeEvent<PublicDelegateT.DocumentT>? = try event.decodeStitchSSE()
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
}
