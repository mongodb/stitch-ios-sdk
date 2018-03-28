public protocol StitchAuthRequestClient {
    func doAuthenticatedRequest<R>(_ stitchReq: R) throws -> Response where R: StitchAuthRequest
    func doAuthenticatedJSONRequest(_ stitchReq: StitchAuthDocRequest) throws -> Any
    func doAuthenticatedJSONRequestRaw(_ stitchReq: StitchAuthDocRequest) throws -> Response
}
