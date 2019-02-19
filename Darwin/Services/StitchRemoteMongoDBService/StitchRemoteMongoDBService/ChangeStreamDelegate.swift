import Foundation
import StitchCoreRemoteMongoDBService

/**
 * A delegate provided when opening a change stream. The methods called by this delegate will be called whenever the
 * stream receives an event or encounters an error.
 */
public protocol ChangeStreamDelegate: class {
    /**
     * Called when the change stream receives a MongoDB Change Event. The change event is generic with respect to the
     * type of the documents from the collection. In most collections this will be the `Document` type from
     * `MongoSwift`, but you can customize it to have your own type.
     *
     * - parameter event: the event received on the stream
     */
    func didReceive<DocumentT: Decodable>(event: ChangeEvent<DocumentT>)

    /**
     * Called when the change stream encounters an error. Errors are uncommon, but may happen if the HTTP stream
     * from the Stitch server sends invalid or corrupted events.
     *
     * - parameter streamError: the error that the stream encountered
     */
    func didReceive(streamError: Error)

    /**
     * Called when the initial opening of the stream is complete, meaning that the stream will receive future events
     * that the user is able to see via rules, until the stream is closed.
     */
    func didOpen()

    /**
     * Called when the stream is closed, meaning there will be no more incoming events.
     */
    func didClose()
}
