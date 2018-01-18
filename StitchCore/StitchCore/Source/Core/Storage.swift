import Foundation

/// Storage allows us to store arbitrary data via
/// an arbitrary source. The protocol is modeled
/// after \(Foundation.UserDefaults).
public protocol Storage {
    /// Initialize new Storage unit
    /// - parameter suiteName: namespace for this storage suite
    /// - returns: a new Storage unit, or nil if the suiteName is invalid
    init?(suiteName: String?)

    /// Read value for key
    /// - parameter forKey key: key to read from
    /// - returns: value for key
    func value(forKey key: String) -> Any?

    /// Set value for key
    /// - parameter value: value to save
    /// - parameter forKey key: key to save value for
    mutating func set(_ value: Any?, forKey key: String)

    /// Remove object for key
    /// - parameter forKey key: key to remove value for
    mutating func removeObject(forKey key: String)
}

/// Failover implementation of the Storage protocol
/// in the event that no other storage unit can
/// be found.
internal struct MemoryStorage: Storage {
    /// Namespace of this suite
    private let suiteName: String
    /// Internal storage unit
    private var storage: [String: Any] = [:]

    init?(suiteName: String?) {
        guard let suiteName = suiteName else {
            return nil
        }

        self.suiteName = suiteName
    }

    func value(forKey key: String) -> Any? {
        return self.storage["\(suiteName).\(key)"]
    }

    mutating func set(_ value: Any?, forKey key: String) {
        self.storage["\(suiteName).\(key)"] = value
    }

    mutating func removeObject(forKey key: String) {
        self.storage.removeValue(forKey: "\(suiteName).\(key)")
    }
}

/// Protocol conformance for Foundation.UserDefaults
extension UserDefaults: Storage {}
