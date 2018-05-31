import Foundation
@testable import StitchCore

final class MockStitchRequestClientProto: StitchRequestClient {
    init() {
        // do nothing
    }
    
    init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) {
        // do nothing
    }
    
    public var doRequestMock = FunctionMockUnitOneArg<Response, StitchRequest>()
    func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return try doRequestMock.throwingRun(arg1: stitchReq)
    }
}
