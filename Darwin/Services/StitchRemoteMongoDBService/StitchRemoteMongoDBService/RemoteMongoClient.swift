import Foundation
import StitchCore
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

private final class RemoteMongoClientFactory: NamedThrowingServiceClientFactory {
    typealias ClientType = RemoteMongoClient

    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> RemoteMongoClient {
        return RemoteMongoClient.init(
            withClient: try CoreRemoteMongoClientFactory.shared.client(
                withService: serviceClient,
                withAppInfo: clientInfo),
            withDispatcher: OperationDispatcher.init(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * The `remoteMongoClientFactory` can be used to create a `RemoteMongoClient` with a `StitchAppClient`.
 * 
 * Use this with `StitchAppClient.serviceClient(fromFactory:withName)` to get a `RemoteMongoClient`.
 */
public let remoteMongoClientFactory =
    AnyNamedThrowingServiceClientFactory<RemoteMongoClient>(factory: RemoteMongoClientFactory())

/**
 * The `RemoteMongoClient` enables reading and writing on a MongoDB database via the Stitch MongoDB service.
 *
 * You can create one by using `remoteMongoClientFactory` with `StitchAppClient`'s
 * `serviceClient(fromFactory:withName)` method.
 *
 * It provides access to instances of `RemoteMongoDatabase`, which in turn provide access to specific
 * `RemoteMongoCollection`s that hold your data.
 *
 * - Note:
 * Before you can read or write data, a user must log in. See `StitchAuth`.
 *
 * - SeeAlso:
 * `StitchAppClient`, `RemoteMongoDatabase`, `RemoteMongoCollection`
 */
public class RemoteMongoClient {
    private let dispatcher: OperationDispatcher
    private let proxy: CoreRemoteMongoClient

    internal init(withClient client: CoreRemoteMongoClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }

    /**
     * Gets a `RemoteMongoDatabase` instance for the given database name.
     *
     * - parameter name: the name of the database to retrieve
     */
    public func db(_ name: String) -> RemoteMongoDatabase {
        return RemoteMongoDatabase.init(withDatabase: proxy.db(name), withDispatcher: dispatcher)
    }
}
