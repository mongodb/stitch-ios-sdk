import Foundation
import StitchCore
import StitchCore_iOS
import StitchCoreServicesMongoDbRemote

private final class RemoteMongoDbServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = RemoteMongoClient
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> RemoteMongoClient {
        return RemoteMongoClient.init(
            withClient: CoreRemoteMongoClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher.init(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * A class which can be used to get database and collection objects which can be used to interact with MongoDB data via
 * the Stitch MongoDB service.
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
     * Gets a `CoreRemoteMongoDatabase` instance for the given database name.
     *
     * - parameter name: the name of the database to retrieve
     */
    public func db(_ name: String) -> RemoteMongoDatabase {
        return RemoteMongoDatabase.init(withDatabase: proxy.db(name), withDispatcher: dispatcher)
    }
}

public final class RemoteMongoDbService {
    public static let sharedFactory =
        AnyNamedServiceClientFactory<RemoteMongoClient>(factory: RemoteMongoDbServiceClientFactory())
}
