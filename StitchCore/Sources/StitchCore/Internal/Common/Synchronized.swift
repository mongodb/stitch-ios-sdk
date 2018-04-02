import Foundation

/**
 * Executes the code in the `block` parameter in a synchronized manner by locking it on the `lock` parameter. Classes
 * can be made synchronized by wrapping their method calls in a `try sync(self) { /* method code goes here */ }` block.
 *
 * - parameters:
 *     - lock: The object to use as a lock to synchronize execution of blocks.
 *     - block: The synchronized code to execute when no one else is holding the provided lock.
 */
public func sync<T>(_ lock: Any, _ block: () throws -> (T)) throws -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try block()
}
