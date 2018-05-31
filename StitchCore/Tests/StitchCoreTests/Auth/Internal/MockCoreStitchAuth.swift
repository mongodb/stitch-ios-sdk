import Foundation
import MongoSwift
import MockUtils
@testable import StitchCore

struct StubAuthRoutes: StitchAuthRoutes {
    var sessionRoute: String = ""
    
    var profileRoute: String = ""
    
    var baseAuthRoute: String = ""
    
    func authProviderRoute(withProviderName providerName: String) -> String {
        return ""
    }
    
    func authProviderLoginRoute(withProviderName providerName: String) -> String {
        return ""
    }
    
    func authProviderLinkRoute(withProviderName providerName: String) -> String {
        return ""
    }
}

final class StubStitchRequestClient: StitchRequestClient {
    init() { }
    
    init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) { }
    
    func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return Response.init(statusCode: 500, headers: [:], body: nil)
    }
}

final class MockCoreStitchAuth<TStitchUser>: CoreStitchAuth<TStitchUser> where TStitchUser: CoreStitchUser {
    // concrete classes in Swift are a little tricky to mock. we can't do a true mock, since super.init must always be
    // called in Swift. This init makes sure that the super init runs without an error.
    public init() {
        self.getAuthInfoMock.doReturn(result: nil) // necessary for init() to run without failing
        try! super.init(requestClient: StubStitchRequestClient.init(),
                        authRoutes: StubAuthRoutes.init(),
                        storage: MemoryStorage(),
                        startRefresherThread: false)
        self.getAuthInfoMock.clearStubs()
        self.getAuthInfoMock.clearInvocations()
    }
    
    public var isLoggedInMock = FunctionMockUnit<Bool>()
    override var isLoggedIn: Bool {
        return isLoggedInMock.run()
    }
    
    public var getAuthInfoMock = FunctionMockUnit<AuthInfo?>()
    override internal(set) var authInfo: AuthInfo? {
        get { return getAuthInfoMock.run() }
        set { }
    }
    
    public var refreshAccessTokenMock = FunctionMockUnit<Void>()
    override internal func refreshAccessToken() {
        return refreshAccessTokenMock.run()
    }
}
