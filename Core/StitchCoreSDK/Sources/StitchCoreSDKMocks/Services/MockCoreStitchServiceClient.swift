import Foundation
import MongoSwift
import MockUtils
@testable import StitchCoreSDK

public final class MockCoreStitchServiceClient: CoreStitchServiceClient {
    public func bind(binder: StitchServiceBinder) {

    }

    public func onRebindEvent(_ rebindEvent: RebindEvent) {

    }

    public var serviceName: String?

    public init() { }
    public var callFunctionMock = FunctionMockUnitThreeArgs<Void, String, [BSONValue], TimeInterval?>()
    public func callFunction(withName name: String,
                             withArgs args: [BSONValue],
                             withRequestTimeout requestTimeout: TimeInterval?) throws {
        return try callFunctionMock.throwingRun(arg1: name, arg2: args, arg3: requestTimeout)
    }

    public var callFunctionWithDecodingMock =
        FunctionMockUnitThreeArgs<Decodable, String, [BSONValue], TimeInterval?>()
    public func callFunction<T>(withName name: String,
                                withArgs args: [BSONValue],
                                withRequestTimeout requestTimeout: TimeInterval?) throws -> T where T: Decodable {
        if let result = try callFunctionWithDecodingMock.throwingRun(
            arg1: name, arg2: args, arg3: requestTimeout
        ) as? T {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
    public var streamFunctionMock =
        FunctionMockUnitThreeArgs<RawSSEStream, String, [BSONValue], SSEStreamDelegate?>()
    public func streamFunction(
        withName name: String,
        withArgs args: [BSONValue],
        delegate: SSEStreamDelegate? = nil
    ) throws -> RawSSEStream {
        return try streamFunctionMock.throwingRun(arg1: name, arg2: args, arg3: delegate)
    }
}
