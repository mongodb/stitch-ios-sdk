/**
 * Generic class holding a weak reference to an object.
 */
public class WeakReference<T: AnyObject> {
    public private(set) weak var reference: T?
    public init(_ reference: T) {
        self.reference = reference
    }
}

/**
 * Generic class holding an unowned reference to an object.
 */
public class UnownedReference<T: AnyObject> {
    public private(set) unowned var reference: T
    public init(_ reference: T) {
        self.reference = reference
    }
}
