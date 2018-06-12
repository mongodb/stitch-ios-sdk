import XCTest
import MongoSwift
import Swifter
@testable import StitchCoreSDK

struct MockStitchUser: CoreStitchUser {
    var id: String = ""

    var loggedInProviderType: StitchProviderType = .anonymous

    var loggedInProviderName: String = ""

    var userType: String = ""

    var profile: StitchUserProfile =
        StitchUserProfileImpl.init(
            userType: "anon-user",
            identities: [APIStitchUserIdentity.init(id: ObjectId().description,
                                                    providerType: "anon-user")],
            data: APIExtendedUserProfileImpl.init()
        )

    var identities: [StitchUserIdentity] = []

    static func ==(lhs: MockStitchUser,
                    rhs: MockStitchUser) -> Bool {
        return lhs.id == rhs.id
    }

    init() {}
    init(id: String,
         loggedInProviderType: StitchProviderType,
         loggedInProviderName: String,
         profile: StitchUserProfile) {
        self.id = id
        self.loggedInProviderType = loggedInProviderType
        self.loggedInProviderName = loggedInProviderName
        self.profile = profile
    }
}

public final class AtomicPort {
    private var _value: UInt16 {
        didSet {
            if _value >= UInt16.max {
                fatalError("no ports remaining for mock server. please clean up some resources")
            }
        }
    }

    fileprivate init(value initialValue: UInt16 = 8079) {
        _value = initialValue
    }

    public func incrementAndGet() -> UInt16 {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        _value += 1
        return _value
    }
}

let atomicPort = AtomicPort()

let testDefaultRequestTimeout: TimeInterval = 15.0

private func start(server: HttpServer) -> UInt16 {
    repeat {
        do {
            let port = atomicPort.incrementAndGet()
            try server.start(port)
            return port
        } catch _ {
        }
    } while true
}

open class StitchXCTestCase: XCTestCase {
    lazy var server = HttpServer()
    internal private(set) var baseURL: String = ""

    open override func setUp() {
        let port = start(server: self.server)
        self.baseURL = "http://localhost:\(port)"
    }

    open override func tearDown() {
        self.server.stop()
    }
}
