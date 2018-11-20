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

internal class DarwinNetworkMonitor: NetworkMonitor {
    private static var _shared: DarwinNetworkMonitor?

    private var networkStateListeners = [NetworkStateListener]()
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

    var isConnected: Bool {
        switch flags {
        case .reachable?: return true
        default: return false
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
            (reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) in
            guard let info = info else { return }

            // Gets the `Handler` object from the context info
            let handler = Unmanaged<DarwinNetworkMonitor>.fromOpaque(info).takeUnretainedValue()

            handler.queue.async {
                handler.flags = flags
            }
        }

        // Registers the callback. `callbackClosure` is the closure where we manage the callback implementation
        if !SCNetworkReachabilitySetCallback(reachability, callbackClosure, &context) {
            // Not able to set the callback
            throw ReachabilityError.UnableToSetCallback
        }

        // Sets the dispatch queue which is `DispatchQueue.main` for this example. It can be also a background queue
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

    func add(networkStateListener listener: NetworkStateListener) {
        self.networkStateListeners.append(listener)
    }

    func remove(networkStateListener listener: NetworkStateListener) {
        self.networkStateListeners.removeAll(where: {$0 === listener})
    }

    func stopNotifier() {
//        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
//        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
    }
//
//    func setReachabilityFlags() throws {
//        try reachabilitySerialQueue.sync { [unowned self] in
//            var flags = SCNetworkReachabilityFlags()
//            if !SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags) {
//                self.stopNotifier()
//                throw ReachabilityError.UnableToGetInitialFlags
//            }
//
//            self.flags = flags
//        }
//    }

    func reachabilityChanged() {
        self.networkStateListeners.forEach({ $0.onNetworkStateChanged() })
    }
}
