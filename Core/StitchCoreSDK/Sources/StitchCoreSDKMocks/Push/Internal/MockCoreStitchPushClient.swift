import Foundation
import MockUtils
import MongoSwift
@testable import StitchCoreSDK

public final class MockCoreStitchPushClient: CoreStitchPushClient {
    public init() { }
    
    public var registerInternalMock = FunctionMockUnitOneArg<Void, Document>()
    public func registerInternal(withRegistrationInfo registrationInfo: Document) throws {
        return try registerInternalMock.throwingRun(arg1: registrationInfo)
    }
    
    public var deregisterInternalMock = FunctionMockUnit<Void>()
    public func deregisterInternal() throws {
        return try deregisterInternalMock.throwingRun()
    }
}
