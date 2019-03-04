public protocol AuthMonitor {
    var isLoggedIn: Bool { get }
    var activeUserId: String? { get }
}
