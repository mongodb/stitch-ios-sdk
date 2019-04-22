import Foundation
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

/**
 * A MongoDB Change Stream session. This can be used to get or change the delegate that reacts to change events on
 * this stream. It can also be used to close open streams.
 */
public class ChangeStreamSession<DocumentT: Codable> {
    /**
     * The delegate for this `ChangeStreamSession`. This is the class that will react to incoming events. A delegate is
     * set at the time the `watch` function is called, but a new delegate may also be set here. This delegate type
     * must conform to `ChangeStreamDelegate`
     *
     * - warning the delegate is held by the change stream as a weak reference. If the delegate becomes
     *           deallocated, the stream will automatically close the next time an event is received. If you are
     *           setting a new delegate, make sure you do so before the previous delegate is deallocated.
     */
    public var delegate: ChangeStreamType<DocumentT>? {
        get {
            return self.internalDelegate.changeStreamType
        }
        set(newValue) {
            self.internalDelegate.changeStreamType = newValue
        }
    }

    /**
     * Closes the stream so that no more events will be received.
     */
    public func close() {
        self.internalDelegate.close()
    }

    // Internal helper to access the raw stream of the underlying internal delegate
    internal var rawStream: RawSSEStream? {
        get {
            return self.internalDelegate.rawStream
        }
        set(newValue) {
            self.internalDelegate.rawStream = newValue
        }
    }

    // We fully manage this delegate, and it gets deallocated when the session is deallocated, so we are not concerned
    // about reference cycles here
    // swiftlint:disable weak_delegate
    internal var internalDelegate: InternalChangeStreamDelegate<DocumentT>
    // swiftlint:enable weak_delegate

    internal init(changeEventType: ChangeStreamType<DocumentT>) {
        self.internalDelegate = InternalChangeStreamDelegate.init(changeStreamType: changeEventType)
    }
}
