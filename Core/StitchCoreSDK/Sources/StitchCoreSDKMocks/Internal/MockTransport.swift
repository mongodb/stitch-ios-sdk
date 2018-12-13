import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockTransport: Transport {
    public init() { } 
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    public var mockStream = FunctionMockUnitTwoArgs<RawSSEStream, Request, SSEStreamDelegate?>()
    public func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
    public func stream(request: Request, delegate: SSEStreamDelegate? = nil) throws -> RawSSEStream {
        return try mockStream.throwingRun(arg1: request, arg2: delegate)
    }
}
