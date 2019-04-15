// swiftlint:disable force_try
import MongoSwift
import StitchCore
import StitchCoreSDK
@testable import StitchCoreRemoteMongoDBService
@testable import StitchRemoteMongoDBService

private let waitTimeout = UInt64(1e+10)

private class SynchronizedDispatchDeque {
    private let rwLock = ReadWriteLock(label: "sync_test_\(ObjectId().oid)")
    private var workItems = [DispatchWorkItem]()
    var count: Int {
        return workItems.count
    }
    
    func append(_ workItem: DispatchWorkItem) {
        rwLock.write {
            workItems.append(workItem)
        }
    }
    
    func removeFirst() -> DispatchWorkItem {
        return rwLock.write {
            return workItems.removeFirst()
        }
    }
}

/// Synchronously capture the value of a asynchronous callback.
class CallbackJoiner {
    /// Serial queue to run our work items on
    private let joinerQueue = DispatchQueue.init(label: "callbackJoiner.\(ObjectId().oid)")
    /// Synchronized queue of work items
    private var joinerWorkItems = SynchronizedDispatchDeque()
    /// The latest captured value
    private var _capturedValue: Any?
    /// Synchronized getter for latest captured value
    public var capturedValue: Any? {
        // go through the standard synchronized steps
        // to read the captured value from the latest
        // work item
        return value(asType: Any.self)
    }
    
    /// The latest captured value.
    func value<T>(asType type: T.Type = T.self) -> T? {
        // wait for each work item to finish. if a new
        // work item is added to the queue, it will be waited on
        while joinerWorkItems.count > 0 {
            let join = DispatchSemaphore.init(value: 0)
            joinerWorkItems.removeFirst().notify(queue: joinerQueue) {
                join.signal()
            }
            join.wait()
        }
        // coerce the latest captured value to type T,
        // returning the result. previous capturedValues
        // should always have been overwritten at this point
        guard _capturedValue is T? else {
            fatalError(
                "Could not unwrap captured value of type " +
                "\(String(describing: _capturedValue.self)) as \(type)")
        }
        return _capturedValue as? T
    }
    
    /*
     Capture the value of a given callback. This value as the capturedValue,
     or value methods.
     */
    func capture<T>() -> (StitchResult<T>) -> Void {
        // If we want to be able to use this from multiple threads,
        // multiple queues should be used, keyed on the thread ID
        // they are called from. This is currently unnecessary in
        // a testing context.
        guard Thread.isMainThread else {
            fatalError(
                "Callback joiner will exhibit unpredicatable " +
                "behavior if run on multiple threads")
        }
        var stitchResult: StitchResult<T>?
        // synchronously allocate a new work item that handles the callback.
        // append the new work item to our queue
        let wkItem = DispatchWorkItem {
            switch stitchResult! {
            case .success(let result):
                self._capturedValue = result
            case .failure(let error):
                fatalError(error.localizedDescription)
            }
        }
        self.joinerWorkItems.append(wkItem)
        // return the expected callback, running our work item when it
        // is eventually called
        return { result in
            stitchResult = result
            self.joinerQueue.async(execute: wkItem)
        }
    }
}



internal extension RemoteMongoCollection {
    func count(_ filter: Document) -> Int? {
        let joiner = CallbackJoiner()
        self.count(filter, joiner.capture())
        return joiner.value(asType: Int.self)
    }
    
    func find(_ filter: Document) -> [T]? {
        let joiner = CallbackJoiner()
        let readOp = self.find(filter, options: nil)
        readOp.toArray(joiner.capture())
        return joiner.value(asType: [T].self)
    }
    
    func findOne(_ filter: Document) -> Document? {
        let joiner = CallbackJoiner()
        self.findOne(filter, options: nil, joiner.capture())
        return joiner.value()
    }
    
    func updateOne(filter: Document, update: Document) -> RemoteUpdateResult {
        let joiner = CallbackJoiner()
        self.updateOne(filter: filter, update: update, options: nil, joiner.capture())
        return joiner.value()!
    }
    
    @discardableResult
    func insertOne(_ document: T) -> RemoteInsertOneResult? {
        let joiner = CallbackJoiner()
        self.insertOne(document, joiner.capture())
        return joiner.value()
    }
    
    @discardableResult
    func insertMany(_ documents: [T]) -> RemoteInsertManyResult? {
        let joiner = CallbackJoiner()
        self.insertMany(documents, joiner.capture())
        return joiner.value()
    }
    
    func deleteOne(_ filter: Document) -> RemoteDeleteResult? {
        let joiner = CallbackJoiner()
        self.deleteOne(filter, joiner.capture())
        return joiner.value()
    }
}

// These extensions make the CRUD commands synchronous to simplify writing tests.
// These extensions should not be used outside of a testing environment.
internal extension Sync where DocumentT == Document {
    func verifyUndoCollectionEmpty() {
        guard try! self.proxy.dataSynchronizer.undoCollection(for: self.proxy.namespace).count() == 0 else {
            fatalError("CRUD operation leaked documents in undo collection, add breakpoint here and check stack trace")
            return
        }
    }
    
    func configure(
        conflictHandler: @escaping (
        _ documentId: BSONValue,
        _ localEvent: ChangeEvent<DocumentT>,
        _ remoteEvent: ChangeEvent<DocumentT>)  throws -> DocumentT?,
        changeEventDelegate: ((_ documentId: BSONValue, _ event: ChangeEvent<DocumentT>) -> Void)? = nil,
        errorListener:  ((_ error: DataSynchronizerError, _ documentId: BSONValue?) -> Void)? = nil) {
        let joiner = CallbackJoiner()
        self.configure(
            conflictHandler: conflictHandler,
            changeEventDelegate: changeEventDelegate,
            errorListener: errorListener, joiner.capture()
        )
        
        _ = joiner.value(asType: Void.self)
    }
    
    func configure<CH: ConflictHandler, CED: ChangeEventDelegate>(
        conflictHandler: CH,
        changeEventDelegate: CED? = nil,
        errorListener: ErrorListener? = nil
        ) where CH.DocumentT == DocumentT, CED.DocumentT == DocumentT {
        let joiner = CallbackJoiner()
        self.configure(
            conflictHandler: conflictHandler,
            changeEventDelegate: changeEventDelegate,
            errorListener: errorListener,
            joiner.capture()
        )
        _ = joiner.value(asType: Void.self)
    }
    
    func sync(ids: [BSONValue]) {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.sync(ids: ids, joiner.capture())
        return joiner.value(asType: Void.self)!
    }
    
    func desync(ids: [BSONValue]) {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.desync(ids: ids, joiner.capture())
        return joiner.value(asType: Void.self)!
    }
    
    func syncedIds() -> Set<AnyBSONValue> {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.syncedIds(joiner.capture())
        return joiner.value(asType: Set<AnyBSONValue>.self)!
    }
    
    func pausedIds() -> Set<AnyBSONValue> {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.pausedIds(joiner.capture())
        return joiner.value(asType: Set<AnyBSONValue>.self)!
    }
    
    func resumeSync(forDocumentId documentId: BSONValue) -> Bool {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.resumeSync(forDocumentId: documentId, joiner.capture())
        return joiner.value(asType: Bool.self)!
    }
    
    func count(_ filter: Document) -> Int? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.count(filter: filter, options: nil, joiner.capture())
        return joiner.value(asType: Int.self)
    }
    
    func aggregate(_ pipeline: [Document]) -> MongoCursor<Document>? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.aggregate(pipeline: pipeline, options: nil, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)
    }
    
    func find(_ filter: Document) -> MongoCursor<Document>? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.find(filter: filter, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)
    }
    
    func findOne(_ filter: Document) -> Document? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.find(filter: filter, joiner.capture())
        return joiner.value(asType: MongoCursor<Document>.self)?.next()
    }
    
    func updateOne(filter: Document, update: Document) -> SyncUpdateResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.updateOne(filter: filter, update: update, options: nil, joiner.capture())
        return joiner.value()
    }
    
    func updateMany(filter: Document, update: Document, options: SyncUpdateOptions? = nil) -> SyncUpdateResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.updateMany(filter: filter, update: update, options: options, joiner.capture())
        return joiner.value()
    }
    
    @discardableResult
    func insertOne(_ document: inout DocumentT) -> SyncInsertOneResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.insertOne(document: document, joiner.capture())
        guard let result: SyncInsertOneResult = joiner.value() else {
            return nil
        }
        
        document["_id"] = result.insertedId
        return result
    }
    
    @discardableResult
    func insertMany(_ documents: inout [DocumentT]) -> SyncInsertManyResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.insertMany(documents: documents, joiner.capture())
        guard let result: SyncInsertManyResult = joiner.value() else {
            return nil
        }
        
        result.insertedIds.forEach {
            documents[$0.key]["_id"] = $0.value
        }
        
        return result
    }
    
    func deleteOne(_ filter: Document) -> SyncDeleteResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.deleteOne(filter: filter, joiner.capture())
        return joiner.value()
    }
    
    func deleteMany(_ filter: Document) -> SyncDeleteResult? {
        defer { verifyUndoCollectionEmpty() }
        let joiner = CallbackJoiner()
        self.deleteMany(filter: filter, joiner.capture())
        return joiner.value()
    }
}
