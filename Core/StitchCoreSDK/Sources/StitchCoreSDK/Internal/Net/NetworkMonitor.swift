public protocol NetworkMonitor {
    func isConnected() -> Bool

    func add(networkStateListener listener: NetworkStateListener)

    func remove(networkStateListener listener: NetworkStateListener)
}

public protocol NetworkStateListener: class {
    func onNetworkStateChanged()
}
