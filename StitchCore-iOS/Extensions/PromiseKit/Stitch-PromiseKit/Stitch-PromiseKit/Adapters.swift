import PromiseKit

// swiftlint:disable identifier_name
internal func adapter(_ seal: Resolver<Void>) -> (Error?) -> Void {
    return { error in
        if let error = error {
            seal.reject(error)
        } else {
            seal.fulfill(Void())
        }
    }
}

internal func adapter<T>(_ seal: Resolver<T>) -> (T?, Error?) -> Void {
    return { t, e in
        if let t = t {
            seal.fulfill(t)
        } else if let e = e {
            seal.reject(e)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}

internal func adapter(_ seal: Resolver<Any>) -> (Any?, Error?) -> Void {
    return { t, e in
        if let t = t {
            seal.fulfill(t)
        } else if let e = e {
            seal.reject(e)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}
// swiftlint:enable identifier_name
