import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockStitchRequestClient: StitchRequestClient {
    public let baseURL: String

    public let transport: Transport

    public let defaultRequestTimeout: TimeInterval

    public init() {
        self.baseURL = ""
        self.transport = MockTransport()
        self.defaultRequestTimeout = 0
    }
    public var doRequestMock = FunctionMockUnitOneArg<Response, StitchRequest>()
    public func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return try doRequestMock.throwingRun(arg1: stitchReq)
    }

    public var doStreamRequestMock = FunctionMockUnitTwoArgs<RawSSEStream, StitchRequest, SSEStreamDelegate?>()
    public func doStreamRequest(_ stitchReq: StitchRequest, delegate: SSEStreamDelegate?) throws -> RawSSEStream {
        return try doStreamRequestMock.throwingRun(arg1: stitchReq, arg2: delegate)
    }
}
