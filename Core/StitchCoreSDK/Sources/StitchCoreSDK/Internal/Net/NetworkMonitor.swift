public protocol NetworkMonitor {
    var isConnected: Bool { get }

    func add(networkStateDelegate delegate: NetworkStateDelegate)

    func remove(networkStateDelegate delegate: NetworkStateDelegate)
}

public protocol NetworkStateDelegate: class {
    func onNetworkStateChanged()
}
