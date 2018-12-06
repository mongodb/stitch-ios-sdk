import Foundation
import MongoSwift
import StitchCoreSDK

class NamespaceChangeStreamDelegate: SSEStreamDelegate<SSE<ChangeEvent<Document>>>, NetworkStateDelegate {
    private let namespace: MongoNamespace
    private let service: CoreStitchServiceClient
    private let networkMonitor: NetworkMonitor
    private let authMonitor: AuthMonitor
    private let nsConfig: NamespaceSynchronization

    private var stream: SSEStream<ChangeEvent<Document>>? = nil
    private lazy var tag = "NSChangeStreamListener-\(namespace.description)"
    private lazy var logger = Log.init(tag: tag)

    init(namespace: MongoNamespace,
         config: inout NamespaceSynchronization,
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
        guard authMonitor.isLoggedIn else {
            logger.i("stream END - Logged out")
            return
        }

        let idsToWatch = nsConfig.map({ $0.documentId.value })
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

    var streamDelegates = [SSEStreamDelegate<SSE<ChangeEvent<Document>>>]()
    internal func add(streamDelegate: SSEStreamDelegate<SSE<ChangeEvent<Document>>>) {
        streamDelegates.append(streamDelegate)
    }

    func onNetworkStateChanged() {

    }

    override func on(newEvent event: SSE<ChangeEvent<Document>>) {
        guard let changeEvent = event.data else {
            return
        }

        logger.d(
            "Received ChangeEvent for id: \(changeEvent.id.value) " +
            "of type: \(changeEvent.operationType)")

        streamDelegates.forEach({$0.on(newEvent: event)})
    }

    override func on(stateChangedFor state: SSEStreamState) {
        switch state {
        case .open:
            logger.d("stream open")
        case .closed:
            logger.d("stream closed")
        }
        streamDelegates.forEach({$0.on(stateChangedFor: state)})
    }

    override func on(error: Error) {
        logger.e(error.localizedDescription)
    }
}
