import Foundation
import MongoSwift
import StitchCoreSDK

class NamespaceChangeStreamDelegate: SSEStreamDelegate<SSE<ChangeEvent<Document>>>, NetworkStateDelegate {
    let namespace: MongoNamespace
    let nsConfig: NamespaceSynchronization
    let service: CoreStitchServiceClient
    let networkMonitor: NetworkMonitor
    let authMonitor: AuthMonitor

    private var stream: SSEStream<ChangeEvent<Document>>? = nil
    private lazy var tag = "NSChangeStreamListener-\(namespace.description)"
    private lazy var logger = Log.init(tag: tag)

    init(namespace: MongoNamespace,
         config: NamespaceSynchronization,
         service: CoreStitchServiceClient,
         networkMonitor: NetworkMonitor,
         authMonitor: AuthMonitor) {
        self.namespace = namespace
        self.nsConfig = config
        self.service = service
        self.networkMonitor = networkMonitor
        self.authMonitor = authMonitor
    }

    /**
     Open the event stream
      - returns: true if successfully opened, false if not
     */
    func start() throws {
        logger.i("stream START")
        guard networkMonitor.isConnected else {
            logger.i("stream END - Network disconnected")
            return
        }
        guard !authMonitor.isLoggedIn else {
            logger.i("stream END - Logged out")
            return
        }

        let idsToWatch = nsConfig.map({ $0.documentId })
        guard !idsToWatch.isEmpty else {
            logger.i("stream END - No synchronized documents")
            return
        }

        self.stream = try service.streamFunction(
            withName: "watch",
            withArgs: [
                ["database": namespace.databaseName,
                 "collection": namespace.collectionName,
                 "ids": idsToWatch] as Document
            ])

        self.stream?.delegate = self
    }

    func stop() {
    }
    
    func onNetworkStateChanged() {

    }

    override func on(newEvent event: SSE<ChangeEvent<Document>>) {
        logger.d(try! BSONEncoder().encode(event.data!).description)
    }

    override func on(stateChangedFor state: SSEStreamState) {

    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }
}
