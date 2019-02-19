import Foundation
import StitchCoreRemoteMongoDBService

/**
 * A delegate that must be provided when opening a change stream. The methods called by this delegate will be called
 * whenever the stream receives an event or encounters an error. To implement a class conforming to this protocol,
 * be sure to add a typealias for the type of BSON documents that the delegate will react to. In most cases, this will
 * be `Document`, but if you have specified your own Codable type, specify it instead.
 *
 * ````
 * public class MyNormalDelegate: ChangeStreamDelegate {
 *     typealias DocumentT = Document
 *
 *     public func didReceive(event: ChangeEvent<Document>) {
 *         // react to events
 *     }
 *
 *     // ...other method implementations
 * }

 * public class MyCustomDelegate: ChangeStreamDelegate {
 *     typealias DocumentT = MyCustomType
 *
 *     public func didReceive(event: ChangeEvent<MyCustomType>) {
 *         // react to events
 *     }
 *
 *     // ...other method implementations
 * }
 * ````
 */
public protocol ChangeStreamDelegate: class {
    associatedtype DocumentT: Codable

    /**
     * Called when the change stream receives a MongoDB Change Event. The change event is generic with respect to the
     * type of the documents from the collection. In most collections this will be the `Document` type from
     * `MongoSwift`, but you can customize it to have your own type.
     *
     * - parameter event: the event received on the stream
     */
    func didReceive(event: ChangeEvent<DocumentT>)

    /**
     * Called when the change stream encounters an error. Errors are uncommon, but may happen if the HTTP stream
     * from the Stitch server sends invalid or corrupted events that cannot be decoded.
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
