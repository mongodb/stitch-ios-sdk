import Foundation
import StitchCoreSDK
import SystemConfiguration

public enum ReachabilityError: Error {
    case FailedToCreateWithAddress(sockaddr_in)
    case FailedToCreateWithHostname(String)
    case UnableToSetCallback
    case UnableToSetDispatchQueue
    case UnableToGetInitialFlags
}

// Based on https://github.com/ashleymills/Reachability.swift
internal class DarwinNetworkMonitor: NetworkMonitor {
    private static var _shared: DarwinNetworkMonitor?

    private var networkStateListeners = [NetworkStateDelegate]()
    // Queue where the `SCNetworkReachability` callbacks run
    private let queue = DispatchQueue.init(label: "com.stitch.darwin_network_monitor")
    // Flag used to avoid starting listening if we are already listening
    private var isListening = false

    private var reachability: SCNetworkReachability!

    private var flags: SCNetworkReachabilityFlags? {
        didSet {
            guard flags != oldValue else { return }
            reachabilityChanged()
        }
    }

    var state: NetworkState {
        switch flags {
        case .reachable?: return .connected
        default: return .disconnected
        }
    }

    internal static func shared() throws -> DarwinNetworkMonitor {
        if DarwinNetworkMonitor._shared == nil {
            DarwinNetworkMonitor._shared = try DarwinNetworkMonitor()
        }

        return DarwinNetworkMonitor._shared!
    }

    private init() throws {
        // Checks if we are already listening
        guard !isListening else { return }

        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)

        // Optional binding since `SCNetworkReachabilityCreateWithName` returns an optional object
        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
            let addr_in = withUnsafePointer(to: &zeroAddress) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    $0.pointee
                }
            }
            throw ReachabilityError.FailedToCreateWithAddress(addr_in)
        }

        self.reachability = ref
        // Creates a context
        var context = SCNetworkReachabilityContext(version: 0,
                                                   info: nil,
                                                   retain: nil,
                                                   release: nil,
                                                   copyDescription: nil)
        // Sets `self` as listener object
        context.info = UnsafeMutableRawPointer(Unmanaged<DarwinNetworkMonitor>.passUnretained(self).toOpaque())

        let callbackClosure: SCNetworkReachabilityCallBack? = {
            (reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) in
            guard let info = info else { return }

            // Gets the `Handler` object from the context info
            let handler = Unmanaged<DarwinNetworkMonitor>.fromOpaque(info).takeUnretainedValue()

            handler.queue.async {
                // this has a didSet block that notifies the delegates
                handler.flags = flags
            }
        }

        // Registers the callback. `callbackClosure` is the closure where we manage the callback implementation
        if !SCNetworkReachabilitySetCallback(reachability, callbackClosure, &context) {
            // Not able to set the callback
            throw ReachabilityError.UnableToSetCallback
        }

        // Sets the dispatch queue
        if !SCNetworkReachabilitySetDispatchQueue(reachability, queue) {
            // Not able to set the queue
            throw ReachabilityError.UnableToSetDispatchQueue
        }

        // Runs the first time to set the current flags
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            // Resets the flags stored, in this way `checkReachability` will set the new ones
            strongSelf.flags = nil

            // Reads the new flags
            var flags = SCNetworkReachabilityFlags()
            SCNetworkReachabilityGetFlags(strongSelf.reachability, &flags)

            strongSelf.flags = flags
        }

        isListening = true
    }

    deinit {
        stopNotifier()
    }

    func add(networkStateDelegate delegate: NetworkStateDelegate) {
        self.networkStateListeners.append(delegate)
    }

    func remove(networkStateDelegate delegate: NetworkStateDelegate) {
        self.networkStateListeners.removeAll(where: {$0 === delegate})
    }

    func stopNotifier() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }

    func reachabilityChanged() {
        self.networkStateListeners.forEach({ $0.on(stateChangedFor: state) })
    }
}
