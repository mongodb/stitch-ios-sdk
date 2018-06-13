import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockStitchRequestClient: StitchRequestClient {
    public init() {
        // do nothing
    }
    
    public init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) {
        // do nothing
    }
    
    public var doRequestMock = FunctionMockUnitOneArg<Response, StitchRequest>()
    public func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return try doRequestMock.throwingRun(arg1: stitchReq)
    }
}
