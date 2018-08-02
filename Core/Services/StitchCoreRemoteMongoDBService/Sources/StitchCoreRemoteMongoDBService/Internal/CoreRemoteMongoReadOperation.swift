import Foundation
import MongoSwift
import StitchCoreSDK

public class CoreRemoteMongoReadOperation<T: Codable> {
    /**
     * A `Codable` type associated with this `MongoCollection` instance.
     * This allows `CollectionType` values to be directly inserted into and
     * retrieved from the collection, by encoding/decoding them using the
     * `BsonEncoder` and `BsonDecoder`.
     * This type association only exists in the context of this particular
     * `MongoCollection` instance. It is the responsibility of the user to
     * ensure that any data already stored in the collection was encoded
     * from this same type.
     */
    public typealias CollectionType = T
    
    private let command: String
    private let args: Document
    private let service: CoreStitchServiceClient
    
    internal init(command: String,
                  args: Document,
                  service: CoreStitchServiceClient) {
        self.command = command
        self.args = args
        self.service = service
    }
    
    public func iterator() throws -> CoreRemoteMongoCursor<T> { // -> CoreRemoteMongoIterator {
        return try CoreRemoteMongoCursor<CollectionType>.init(documents: executeRead().makeIterator())
    }
    
    public func first() throws -> T? {
        return try executeRead().first
    }
    
    public func asArray() throws -> [T] {
        return try executeRead()
    }
    
    private func executeRead() throws -> [T] {
        return try service.callFunction(
            withName: self.command,
            withArgs: [self.args],
            withRequestTimeout: nil
        )
    }
}
