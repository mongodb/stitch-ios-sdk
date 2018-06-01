import Foundation
import MockUtils
@testable import StitchCore

public final class MockTransport: Transport {
    public init() { } 
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    public func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
}
