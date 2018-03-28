import Foundation

public func sync<T>(_ lock: Any, _ block: () throws -> (T)) throws -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try block()
}
