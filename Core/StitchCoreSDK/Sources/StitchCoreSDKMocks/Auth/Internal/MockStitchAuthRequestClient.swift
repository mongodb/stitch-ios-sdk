import Foundation
import MockUtils
@testable import StitchCoreSDK

public final class MockStitchAuthRequestClient: StitchAuthRequestClient {
    public init() { }
    public var doAuthenticatedRequestMock = FunctionMockUnitOneArg<Response, StitchAuthRequest>()
    public func doAuthenticatedRequest(_ stitchReq: StitchAuthRequest) throws -> Response {
        return try doAuthenticatedRequestMock.throwingRun(arg1: stitchReq)
    }
    
    public var doAuthenticatedRequestWithDecodingMock = FunctionMockUnitOneArg<Any, StitchAuthRequest>()
    public func doAuthenticatedRequest<DecodedT>(_ stitchReq: StitchAuthRequest) throws -> DecodedT where DecodedT : Decodable {
        if let result = try doAuthenticatedRequestWithDecodingMock.throwingRun(arg1: stitchReq) as? DecodedT {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }

    public var openAuthenticatedStreamMock = FunctionMockUnitOneArg<Any, StitchAuthRequest>()
    public func openAuthenticatedStream<T>(_ stitchReq: StitchAuthRequest) throws -> SSEStream<T> where T : Decodable {
        if let result = try openAuthenticatedStreamMock.throwingRun(arg1: stitchReq) as? SSEStream<T> {
            return result
        } else {
            fatalError("Returning incorrect type from mocked result")
        }
    }
}
