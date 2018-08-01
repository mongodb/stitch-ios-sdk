import Foundation
import MongoSwift
import MockUtils
@testable import StitchCoreSDK

public final class MockCoreStitchServiceClient: CoreStitchServiceClient {
    public init() { }
    public var callFunctionMock = FunctionMockUnitThreeArgs<Void, String, [BsonValue], TimeInterval?>()
    public func callFunction(withName name: String,
                             withArgs args: [BsonValue],
                             withRequestTimeout requestTimeout: TimeInterval?) throws {
        return try callFunctionMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout)
    }
    
    public var callFunctionWithDecodingMock =
        FunctionMockUnitThreeArgs<Decodable, String, [BsonValue], TimeInterval?>()
    public func callFunction<T>(withName name: String,
                                withArgs args: [BsonValue],
                                withRequestTimeout requestTimeout: TimeInterval?) throws -> T where T : Decodable {
        if let result = try callFunctionWithDecodingMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout) as? T {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}
