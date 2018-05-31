import Foundation
@testable import StitchCore

final class MockStitchAuthRequestClient: StitchAuthRequestClient {
    public var doAuthenticatedRequestMock = FunctionMockUnitOneArg<Response, StitchAuthRequest>()
    func doAuthenticatedRequest(_ stitchReq: StitchAuthRequest) throws -> Response {
        return try doAuthenticatedRequestMock.throwingRun(arg1: stitchReq)
    }
    
    public var doAuthenticatedRequestWithDecodingMock = FunctionMockUnitOneArg<Any, StitchAuthRequest>()
    func doAuthenticatedRequest<DecodedT>(_ stitchReq: StitchAuthRequest) throws -> DecodedT where DecodedT : Decodable {
        if let result = try doAuthenticatedRequestWithDecodingMock.throwingRun(arg1: stitchReq) as? DecodedT {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}
