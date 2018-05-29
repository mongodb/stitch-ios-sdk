import Foundation
import MongoSwift
@testable import StitchCore

enum Matcher<Type> {
    case any
    case with(condition: (Type) -> Bool)
}

class FunctionMockUnit<ReturnType> { // takes no args
    var mockedResult: ReturnType?
    var mockedResultSequence: [ReturnType]?
    var thrownError: Error?
    
    var invocations: Int = 0
    
    public func doReturn(result: ReturnType) {
        self.mockedResult = result
        self.mockedResultSequence = nil
        self.thrownError = nil
    }
    
    public func doReturn(resultSequence: [ReturnType]) {
        self.mockedResult = nil
        self.mockedResultSequence = resultSequence.reversed()
        self.thrownError = nil
    }
    
    public func doThrow(error: Error) {
        self.mockedResult = nil
        self.mockedResultSequence = nil
        self.thrownError = error
    }
    
    public func verify(numberOfInvocations: Int) -> Bool {
        return self.invocations == numberOfInvocations
    }
    
    public func throwingRun() throws -> ReturnType {
        if let thrownError = self.thrownError {
            self.invocations += 1
            throw thrownError
        }
        
        return run()
    }
    
    public func run() -> ReturnType {
        self.invocations += 1
        
        // Don't search for a result matcher if return type is void
        if ReturnType.self == Void.self {
            return () as! ReturnType
        }
        
        if let mockedResult = self.mockedResult {
            return mockedResult
        } else if self.mockedResultSequence != nil &&
            !self.mockedResultSequence!.isEmpty{
            return mockedResultSequence!.popLast()!
        }
        fatalError("nothing to return from mocked function")
    }
    
    public func clearStubs() {
        self.mockedResult = nil
        self.mockedResultSequence = nil
        self.thrownError = nil
    }
    
    public func clearInvocations() {
        self.invocations = 0
    }
 }

class FunctionMockUnitOneArg<ReturnType, Arg1T> { // takes one arg
    var mockedResultMatchers: [(Matcher<Arg1T>, ReturnType)] = []
    var throwingMatchers: [(Matcher<Arg1T>, Error)] = []
    
    var capturedInvocations: [Arg1T] = []
    
    func doReturn(result: ReturnType, forArg matcher: Matcher<Arg1T>) {
        self.mockedResultMatchers.append((matcher, result))
    }
    
    func doThrow(error: Error, forArg matcher: Matcher<Arg1T>) {
        self.throwingMatchers.append((matcher, error))
    }
    
    //TODO: return resultSequence for matcher
    
    public func verify(numberOfInvocations: Int, forArg matcher: Matcher<Arg1T>) -> Bool {
        switch matcher {
            
        case .any:
            return capturedInvocations.count == numberOfInvocations
        case .with(let condition):
            return capturedInvocations.count(where: { (arg) -> Bool in
                return condition(arg)
            }) == numberOfInvocations
        }
    }
    
    public func throwingRun(arg1: Arg1T) throws -> ReturnType {
        for throwingMatcher in self.throwingMatchers {
            let matcher = throwingMatcher.0
            let thrownError = throwingMatcher.1
            
            switch matcher {
            case .any:
                capturedInvocations.append(arg1)
                throw thrownError
            case .with(let condition):
                if condition(arg1) {
                    capturedInvocations.append(arg1)
                    throw thrownError
                }
            }
        }
        
        return self.run(arg1: arg1)
    }
    
    public func run(arg1: Arg1T) -> ReturnType {
        capturedInvocations.append(arg1)
        
        // Don't search for a result matcher if return type is void
        if ReturnType.self == Void.self {
            return () as! ReturnType
        }
        
        for resultMatcher in self.mockedResultMatchers {
            let matcher = resultMatcher.0
            let mockResult = resultMatcher.1
            
            switch matcher {
            case .any:
                return mockResult
            case .with(let condition):
                if condition(arg1) {
                    return mockResult
                }
            }
        }

        fatalError("could not find a match to return a value from mocked function")
    }
    
    public func clearStubs() {
        self.mockedResultMatchers = []
        self.throwingMatchers = []
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}

class FunctionMockUnitTwoArgs<ReturnType, Arg1T, Arg2T> { // takes two args
    var mockedResultMatchers: [(Matcher<Arg1T>, Matcher<Arg2T>, ReturnType)] = []
    var throwingMatchers: [(Matcher<Arg1T>, Matcher<Arg2T>, Error)] = []
    
    var capturedInvocations: [(Arg1T, Arg2T)] = []
    
    func doReturn(result: ReturnType, forArg1 matcher1: Matcher<Arg1T>, forArg2 matcher2: Matcher<Arg2T>) {
        self.mockedResultMatchers.append((matcher1, matcher2, result))
    }
    
    func doThrow(error: Error, forArg1 matcher1: Matcher<Arg1T>, forArg2 matcher2: Matcher<Arg2T>) {
        self.throwingMatchers.append((matcher1, matcher2, error))
    }
    
    //TODO: return resultSequence for matcher
    
    public func verify(numberOfInvocations: Int, forArg1 matcher1: Matcher<Arg1T>, forArg2 matcher2: Matcher<Arg2T>) -> Bool {
        var count: Int = 0
        
        capturedInvocations.forEach { (argsTuple) in
            let (arg1, arg2) = argsTuple
            var matched1, matched2: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            
            if matched1 && matched2 {
                count += 1
            }
        }
        
        return count == numberOfInvocations
    }
    
    public func throwingRun(arg1: Arg1T, arg2: Arg2T) throws -> ReturnType {
        for throwingMatcher in self.throwingMatchers {
            let matcher1 = throwingMatcher.0
            let matcher2 = throwingMatcher.1
            let thrownError = throwingMatcher.2
            
            var matched1, matched2: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            
            if matched1 && matched2 {
                capturedInvocations.append((arg1, arg2))
                throw thrownError
            }
        }
        
        return run(arg1: arg1, arg2: arg2)
    }
    
    public func run(arg1: Arg1T, arg2: Arg2T) -> ReturnType {
        capturedInvocations.append((arg1, arg2))
        
        // Don't search for a result matcher if return type is void
        if ReturnType.self == Void.self {
            return () as! ReturnType
        }
        
        for resultMatcher in self.mockedResultMatchers {
            let matcher1 = resultMatcher.0
            let matcher2 = resultMatcher.1
            let mockResult = resultMatcher.2
            
            var matched1, matched2: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            
            if matched1 && matched2 {
                return mockResult
            }
        }
        
        fatalError("could not find a match to return a value from mocked function")
    }
    
    public func clearStubs() {
        self.mockedResultMatchers = []
        self.throwingMatchers = []
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}

class FunctionMockUnitThreeArgs<ReturnType, Arg1T, Arg2T, Arg3T> { // takes three args
    var mockedResultMatchers: [(Matcher<Arg1T>, Matcher<Arg2T>, Matcher<Arg3T>, ReturnType)] = []
    var throwingMatchers: [(Matcher<Arg1T>, Matcher<Arg2T>, Matcher<Arg3T>, Error)] = []
    
    var capturedInvocations: [(Arg1T, Arg2T, Arg3T)] = []
    
    func doReturn(result: ReturnType,
                  forArg1 matcher1: Matcher<Arg1T>,
                  forArg2 matcher2: Matcher<Arg2T>,
                  forArg3 matcher3: Matcher<Arg3T>) {
        self.mockedResultMatchers.append((matcher1, matcher2, matcher3, result))
    }
    
    func doThrow(error: Error,
                 forArg1 matcher1: Matcher<Arg1T>,
                 forArg2 matcher2: Matcher<Arg2T>,
                 forArg3 matcher3: Matcher<Arg3T>) {
        self.throwingMatchers.append((matcher1, matcher2, matcher3, error))
    }
    
    //TODO: return resultSequence for matcher
    
    public func verify(numberOfInvocations: Int,
                       forArg1 matcher1: Matcher<Arg1T>,
                       forArg2 matcher2: Matcher<Arg2T>,
                       forArg3 matcher3: Matcher<Arg3T>) -> Bool {
        var count: Int = 0
        
        capturedInvocations.forEach { (argsTuple) in
            let (arg1, arg2, arg3) = argsTuple
            var matched1, matched2, matched3: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            switch matcher3 {
            case .any:
                matched3 = true
            case .with(let condition):
                matched3 = condition(arg3)
            }
            
            if matched1 && matched2 && matched3 {
                count += 1
            }
        }
        
        return count == numberOfInvocations
    }
    
    public func throwingRun(arg1: Arg1T, arg2: Arg2T, arg3: Arg3T) throws -> ReturnType {
        for throwingMatcher in self.throwingMatchers {
            let matcher1 = throwingMatcher.0
            let matcher2 = throwingMatcher.1
            let matcher3 = throwingMatcher.2
            let thrownError = throwingMatcher.3
            
            var matched1, matched2, matched3: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            switch matcher3 {
            case .any:
                matched3 = true
            case .with(let condition):
                matched3 = condition(arg3)
            }
            
            if matched1 && matched2 && matched3 {
                capturedInvocations.append((arg1, arg2, arg3))
                throw thrownError
            }
        }
        
        return run(arg1: arg1, arg2: arg2, arg3: arg3)
    }
    
    public func run(arg1: Arg1T, arg2: Arg2T, arg3: Arg3T) -> ReturnType {
        capturedInvocations.append((arg1, arg2, arg3))
        
        // Don't search for a result matcher if return type is void
        if ReturnType.self == Void.self {
            return () as! ReturnType
        }
        
        for resultMatcher in self.mockedResultMatchers {
            let matcher1 = resultMatcher.0
            let matcher2 = resultMatcher.1
            let matcher3 = resultMatcher.2
            let mockResult = resultMatcher.3
            
            var matched1, matched2, matched3: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            switch matcher3 {
            case .any:
                matched3 = true
            case .with(let condition):
                matched3 = condition(arg3)
            }
            
            if matched1 && matched2 && matched3 {
                return mockResult
            }
        }
        
        fatalError("could not find a match to return a value from mocked function")
    }
    
    public func clearStubs() {
        self.mockedResultMatchers = []
        self.throwingMatchers = []
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}

extension Collection {
    func count(where predicate: (Element) -> Bool) -> Int {
        var count: Int = 0
        self.forEach { element in
            if(predicate(element) == true) {
                count += 1
            }
        }
        return count
    }
}

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

final class StubUser: CoreStitchUser {
    var id: String = ""
    
    var loggedInProviderType: StitchProviderType = .anonymous
    
    var loggedInProviderName: String = ""
    
    var userType: String = ""
    
    var profile: StitchUserProfile =
        StitchUserProfileImpl.init(userType: "", identities: [], data: APIExtendedUserProfileImpl.init())
    
    var identities: [StitchUserIdentity] = []
}

final class StubStitchRequestClient: StitchRequestClient {
    init() { }
    
    init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) { }
    
    func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return Response.init(statusCode: 500, headers: [:], body: nil)
    }
}

final class MockCoreStitchAuthProto<TStitchUser>: CoreStitchAuth<TStitchUser> where TStitchUser: CoreStitchUser {
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

final class MockTransport: Transport {
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    internal func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
}

final class MockStitchRequestClientProto: StitchRequestClient {
    init() {
        // do nothing
    }
    
    init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) {
        // do nothing
    }
    
    public var doRequestMock = FunctionMockUnitOneArg<Response, StitchRequest>()
    func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return try doRequestMock.throwingRun(arg1: stitchReq)
    }
}

final class MockStitchAuthRequestClient: StitchAuthRequestClient {
    public var doAuthenticatedRequestMock = FunctionMockUnitOneArg<Response, StitchAuthRequest>()
    func doAuthenticatedRequest(_ stitchReq: StitchAuthRequest) throws -> Response {
        return try doAuthenticatedRequestMock.throwingRun(arg1: stitchReq)
    }
    
    public var doAuthenticatedRequestWithDecodingMock = FunctionMockUnitOneArg<Any, StitchAuthRequest>()
    func doAuthenticatedRequest<DecodedT>(_ stitchReq: StitchAuthRequest) throws -> DecodedT where DecodedT : Decodable {
        if let result = try doAuthenticatedRequestWithDecodingMock.throwingRun(arg1: stitchReq) as? DecodedT {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}

final class MockCoreStitchService: CoreStitchService {
    public var callFunctionInternalMock = FunctionMockUnitThreeArgs<Void, String, [BsonValue], TimeInterval?>()
    func callFunctionInternal(withName name: String,
                              withArgs args: [BsonValue],
                              withRequestTimeout requestTimeout: TimeInterval?) throws {
        return try callFunctionInternalMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout)
    }
    
    public var callFunctionInternalWithDecodingMock =
        FunctionMockUnitThreeArgs<Decodable, String, [BsonValue], TimeInterval?>()
    func callFunctionInternal<T>(withName name: String,
                                 withArgs args: [BsonValue],
                                 withRequestTimeout requestTimeout: TimeInterval?) throws -> T where T : Decodable {
        if let result = try callFunctionInternalWithDecodingMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout) as? T {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}
