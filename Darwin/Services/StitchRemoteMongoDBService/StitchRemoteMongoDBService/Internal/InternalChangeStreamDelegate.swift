import Foundation
import StitchCoreSDK
import StitchCoreRemoteMongoDBService
import MongoSwift

/**
 * Internal class which serves as an intermediary between an internal RawSSEStream and a change stream as exposed
 * by the remote MongoDB service.
 */
internal class InternalChangeStreamDelegate<DocumentT: Codable>: SSEStreamDelegate {
    public var changeStreamType: ChangeStreamType<DocumentT>?
    internal var rawStream: RawSSEStream?

    public init(changeStreamType: ChangeStreamType<DocumentT>) {
        self.changeStreamType = changeStreamType
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
        guard let delegate = changeStreamType?.delegate else {
            self.close()
            return
        }

        do {
            if !delegate.useCompactEvents {
                guard let changeEvent: ChangeEvent<DocumentT> = try event.decodeStitchSSE() else {
                    self.on(error: StitchError.requestError(
                        withError: RuntimeError.internalError(message: "invalid event received from stream"),
                        withRequestErrorCode: .decodingError))
                    return
                }

                delegate.didReceive(event: changeEvent)
            } else {
                guard let changeEvent: CompactChangeEvent<DocumentT> = try event.decodeStitchSSE() else {
                    self.on(error: StitchError.requestError(
                        withError: RuntimeError.internalError(message: "invalid event received from stream"),
                        withRequestErrorCode: .decodingError))
                    return
                }

                delegate.didReceive(event: changeEvent)
            }
        } catch let err {
            self.on(error: StitchError.requestError(withError: err, withRequestErrorCode: .decodingError))
        }
    }

    override final public func on(error: Error) {
        guard let delegate = changeStreamType?.delegate else {
            self.close()
            return
        }

        // Dispatch error to user stream
        delegate.didReceive(streamError: error)
    }

    override final public func on(stateChangedFor state: SSEStreamState) {
        guard let delegate = changeStreamType?.delegate else {
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
