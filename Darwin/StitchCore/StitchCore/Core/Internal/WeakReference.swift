import Foundation

/**
 * Generic class holding a weak reference to an object.
 */
class WeakReference<T> where T: AnyObject {

    private(set) weak var value: T?

    init(_ value: T?) {
        self.value = value
    }
}
