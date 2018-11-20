public protocol NetworkMonitor {
    var isConnected: Bool { get }

    func add(networkStateListener listener: NetworkStateListener)

    func remove(networkStateListener listener: NetworkStateListener)
}

public protocol NetworkStateListener: class {
    func onNetworkStateChanged()
}
