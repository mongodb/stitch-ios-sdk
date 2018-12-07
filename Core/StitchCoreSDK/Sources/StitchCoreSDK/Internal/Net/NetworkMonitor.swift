/// The state of the network
public enum NetworkState {
    /// The network is currently connected
    case connected
    /// The network is currently disconnected
    case disconnected
}

public protocol NetworkMonitor {
    var state: NetworkState { get }

    func add(networkStateDelegate delegate: NetworkStateDelegate)

    func remove(networkStateDelegate delegate: NetworkStateDelegate)
}

public protocol NetworkStateDelegate: class {
    func on(stateChangedFor state: NetworkState)
}
