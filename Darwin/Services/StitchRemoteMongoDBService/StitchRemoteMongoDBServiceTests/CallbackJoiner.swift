import Foundation
import StitchCoreSDK
import StitchCore
import XCTest
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

private class SynchronizedDispatchDeque {
    private let rwLock = ReadWriteLock(label: "sync_test_\(ObjectId().hex)")
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
    private let joinerQueue = DispatchQueue.init(label: "callbackJoiner.\(ObjectId().hex)")
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
                XCTFail(error.localizedDescription)
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

/// Synchronously capture the value of a asynchronous callback.
class ThrowingCallbackJoiner {
    /// Serial queue to run our work items on
    private let joinerQueue = DispatchQueue.init(label: "throwingCallbackJoiner.\(ObjectId().hex)")
    /// Synchronized queue of work items
    private var joinerWorkItems = SynchronizedDispatchDeque()
    /// The latest captured value
    private var _capturedValue: Any?

    /// The latest captured value.
    func value<T>(asType type: T.Type = T.self) throws -> T? {
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
        if let err = _capturedValue as? Error {
            throw err
        }

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
                self._capturedValue = error
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

private let queue = DispatchQueue.init(label: "async_await_queue")

// swiftlint:disable identifier_name
func await<T>(_ block: @escaping (@escaping (T) -> Void) -> Void) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block { result in
        defer { dispatchGroup.leave() }
        retVal = result
    }
    dispatchGroup.wait()
    return retVal
}

func await<T, A>(_ block: ((@escaping (A, (@escaping (T) -> Void)) -> Void)), _ a: A) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block(a) { result in
        defer { dispatchGroup.leave() }
        retVal = result
    }
    dispatchGroup.wait()
    return retVal
}

func await<T, A, B>(_ block: ((@escaping (A, B, (@escaping (T) -> Void)) -> Void)), _ a: A, _ b: B) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block(a, b) { result in
        defer { dispatchGroup.leave() }
        retVal = result
    }
    dispatchGroup.wait()
    return retVal
}

func await<T, A, B, C>(_ block: ((@escaping (A, B, C, (@escaping (T) -> Void)) -> Void)), _ a: A, _ b: B, _ c: C) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block(a, b, c) { result in
        defer { dispatchGroup.leave() }
        retVal = result
    }
    dispatchGroup.wait()
    return retVal
}

func async(_ block: @escaping () -> Void) {
    queue.async {
        block()
    }
}
