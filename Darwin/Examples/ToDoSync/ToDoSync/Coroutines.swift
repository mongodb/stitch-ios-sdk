import Foundation
import StitchSDK


private let queue = DispatchQueue.init(label: "async_await_queue")

func await<T>(_ block: @escaping (@escaping (StitchResult<T>) -> Void) -> ()) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block { result in
        defer { dispatchGroup.leave() }
        guard case .success(let value) = result else {
            return
        }
        retVal = value
    }
    dispatchGroup.wait()
    return retVal
}

func await<T, A>(_ block: ((@escaping (A, (@escaping (StitchResult<T>) -> Void)) -> ())), _ a: A) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block(a) { result in
        defer { dispatchGroup.leave() }
        guard case .success(let value) = result else {
            return
        }
        retVal = value
    }
    dispatchGroup.wait()
    return retVal
}

func await<T, A, B, C>(_ block: ((@escaping (A, B, C, (@escaping (StitchResult<T>) -> Void)) -> ())), _ a: A, _ b: B, _ c: C) -> T {
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var retVal: T!
    block(a, b, c) { result in
        defer { dispatchGroup.leave() }
        guard case .success(let value) = result else {
            return
        }
        retVal = value
    }
    dispatchGroup.wait()
    return retVal
}

func async(_ block: @escaping () -> Void) {
    queue.async {
        block()
    }
}
