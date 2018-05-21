import XCTest
import BSON
@testable import StitchCore

private let appRoutes = StitchAppRoutes.init(clientAppId: "")
private let mockServiceName = "mockService"
private let mockFunctionName = "mockFunction"
private let mockArgs = [0, 1, 2]
private let expectedDoc: Document = [
    "name": mockFunctionName,
    "service": mockServiceName,
    "arguments": mockArgs
]

class CoreStitchServiceTests: XCTestCase {
    private class MockAuthRequestClient: StitchAuthRequestClient {
        func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest {
            return Response.init(statusCode: 200, headers: [:], body: nil)
        }

        func doAuthenticatedJSONRequest(_ stitchReq: StitchAuthDocRequest) throws -> Any {
            XCTAssertEqual(stitchReq.method, .post)
            XCTAssertEqual(stitchReq.path, appRoutes.serviceRoutes.functionCallRoute)
            XCTAssertEqual(stitchReq.document, expectedDoc)
            return self
        }

        func doAuthenticatedJSONRequestRaw(_ stitchReq: StitchAuthDocRequest) throws -> Response {
            return Response.init(statusCode: 200, headers: [:], body: nil)
        }
    }

    func testCallFunctionInternal() throws {
        let coreStitchService = CoreStitchService.init(requestClient: MockAuthRequestClient(),
                                                       routes: appRoutes.serviceRoutes,
                                                       name: mockServiceName)

        _ = try coreStitchService.callFunctionInternal(withName: mockFunctionName,
                                                           withArgs: mockArgs)
    }
}
