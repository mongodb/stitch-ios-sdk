import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockTransport: Transport {
    public init() { } 
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    public var mockStream = FunctionMockUnitOneArg<SSEStream, Request>()
    public func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
    public func stream<T: RawSSE>(request: Request) throws -> AnyRawSSEStream<T> {
        return try mockStream.throwingRun(arg1: request)
    }
}
