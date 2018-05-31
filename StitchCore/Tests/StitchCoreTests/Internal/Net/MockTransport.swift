import Foundation
import MockUtils
@testable import StitchCore

final class MockTransport: Transport {
    public var mockRoundTrip = FunctionMockUnitOneArg<Response, Request>()
    internal func roundTrip(request: Request) throws -> Response {
        return try mockRoundTrip.throwingRun(arg1: request)
    }
}
