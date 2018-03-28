import Foundation
import ExtendedJSON

private func inspectResponse(response: Response) throws -> Response {
    guard response.statusCode >= 200,
        response.statusCode < 300 else {
        throw StitchErrorCodable.handleRequestError(response: response)
    }

    return response
}

public protocol StitchRequestClient {
    init(baseURL: String, transport: Transport)

    func doRequest<R>(_ stitchReq: R) throws -> Response where R: StitchRequest
    func doJSONRequestRaw(_ stitchReq: StitchDocRequest) throws -> Response
}

public final class StitchRequestClientImpl: StitchRequestClient {
    private let baseURL: String
    private let transport: Transport

    public init(baseURL: String, transport: Transport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func doRequest<R>(_ stitchReq: R) throws -> Response where R: StitchRequest {
        return try inspectResponse(
            response: transport.roundTrip(request: buildRequest(stitchReq))
        )
    }

    public func doJSONRequestRaw(_ stitchReq: StitchDocRequest) throws -> Response {
        return try doRequest(StitchRequestBuilderImpl { builder in
            builder.body = try! BSONEncoder().encode(stitchReq.document,
                                                      shouldIncludeSourceMap: false)
            builder.headers = [
                Headers.contentType.rawValue: ContentTypes.applicationJson.rawValue
            ]
            builder.path = stitchReq.path
            builder.method = stitchReq.method
        }.build())
    }

    private func buildRequest<R>(_ stitchReq: R) throws -> Request where R: StitchRequest {
        return try RequestBuilder { builder in
            builder.method = stitchReq.method
            builder.url = "\(self.baseURL)\(stitchReq.path)"
            builder.headers = stitchReq.headers
            builder.body = stitchReq.body
        }.build()
    }
}
