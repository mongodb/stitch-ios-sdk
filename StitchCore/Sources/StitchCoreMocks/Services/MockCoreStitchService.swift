import Foundation
import MongoSwift
import MockUtils
@testable import StitchCore

public final class MockCoreStitchService: CoreStitchServiceClient {
    public init() { }
    public var callFunctionInternalMock = FunctionMockUnitThreeArgs<Void, String, [BsonValue], TimeInterval?>()
    public func callFunctionInternal(withName name: String,
                                     withArgs args: [BsonValue],
                                     withRequestTimeout requestTimeout: TimeInterval?) throws {
        return try callFunctionInternalMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout)
    }
    
    public var callFunctionInternalWithDecodingMock =
        FunctionMockUnitThreeArgs<Decodable, String, [BsonValue], TimeInterval?>()
    public func callFunctionInternal<T>(withName name: String,
                                        withArgs args: [BsonValue],
                                        withRequestTimeout requestTimeout: TimeInterval?) throws -> T where T : Decodable {
        if let result = try callFunctionInternalWithDecodingMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout) as? T {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}
