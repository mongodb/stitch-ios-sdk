import PromiseKit

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
    return { value, error in
        if let value = value {
            seal.fulfill(value)
        } else if let error = error {
            seal.reject(error)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}
