public enum NetworkState {
    case connected, disconnected
}

public protocol NetworkMonitor {
    var state: NetworkState { get }

    func add(networkStateDelegate delegate: NetworkStateDelegate)

    func remove(networkStateDelegate delegate: NetworkStateDelegate)
}

public protocol NetworkStateDelegate: class {
    func on(stateChangedFor state: NetworkState)
}
