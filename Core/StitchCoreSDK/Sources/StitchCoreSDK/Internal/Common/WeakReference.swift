public class WeakReference<T: AnyObject> {
    public private(set) weak var reference: T?
    public init(_ reference: T) {
        self.reference = reference
    }
}

public class UnownedReference<T: AnyObject> {
    public private(set) unowned var reference: T
    public init(_ reference: T) {
        self.reference = reference
    }
}
