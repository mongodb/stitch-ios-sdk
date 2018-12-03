import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockTransport: Transport {
    public init() { } 
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    public var mockStream = FunctionMockUnitOneArg<EventStream, Request>()
    public func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
    public func stream(request: Request) throws -> EventStream {
        return try mockStream.throwingRun(arg1: request)
    }
}
