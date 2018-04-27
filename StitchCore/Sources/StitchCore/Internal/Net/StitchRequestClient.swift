import Foundation
import ExtendedJSON

/**
 * Returns the provided response if its status code is in the 200 range, throws a `StitchError` otherwise.
 */
private func inspectResponse(response: Response) throws -> Response {
    guard response.statusCode >= 200,
        response.statusCode < 300 else {
        throw StitchErrorCodable.handleError(forResponse: response)
    }

    return response
}

/**
 * A protocol defining the methods necessary to make requests to the Stitch server.
 */
public protocol StitchRequestClient {
    /**
     * Initializes the request client with the provided base URL and `Transport`.
     */
    init(baseURL: String, transport: Transport, transportTimeout: TimeInterval)

    /**
     * Performs a request against the Stitch server with the given `StitchRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    func doRequest<R>(_ stitchReq: R) throws -> Response where R: StitchRequest

    /**
     * Performs a request against the Stitch server with the given `StitchDocRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    func doJSONRequestRaw(_ stitchReq: StitchDocRequest) throws -> Response
}

/**
 * The implementation of `StitchRequestClient`.
 */
public final class StitchRequestClientImpl: StitchRequestClient {
    /**
     * The base URL of the Stitch server to which this client will make requests.
     */
    private let baseURL: String

    /**
     * The `Transport` which this client will use to make round trips to the Stitch server.
     */
    private let transport: Transport
    
    /**
     * The number of seconds that the underlying `Transport` should spend on an HTTP round trip before failing with an
     * error. Does not override any timeout settings configured by the underlying transport.
     */
    private let transportTimeout: TimeInterval

    /**
     * Initializes the request client with the provided base URL and `Transport`.
     */
    public init(baseURL: String, transport: Transport, transportTimeout: TimeInterval) {
        self.baseURL = baseURL
        self.transport = transport
        self.transportTimeout = transportTimeout
    }

    /**
     * Performs a request against the Stitch server with the given `StitchRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    public func doRequest<R>(_ stitchReq: R) throws -> Response where R: StitchRequest {
        let transportTask = DispatchGroup.init()
        var response: Response!
        var errorToThrow: Error?
        
        transportTask.enter()
        DispatchQueue.global().async {
            do {
                response = try self.transport.roundTrip(request: self.buildRequest(stitchReq))
            } catch let error {
                // Wrap the error from the transport in a `StitchError.requestError`
                errorToThrow = StitchError.requestError(withError: error, withRequestErrorCode: .transportError)
            }
            
            transportTask.leave()
        }
        
        let taskResult = transportTask.wait(timeout: DispatchTime.now() + self.transportTimeout)
        
        switch taskResult {
        case .success:
            if let error = errorToThrow {
                throw error
            }
            
            return try inspectResponse(response: response)
            
        case .timedOut:
            throw StitchError.requestError(withError: nil, withRequestErrorCode: .transportTimeoutError)
        }
    }

    /**
     * Performs a request against the Stitch server with the given `StitchDocRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    public func doJSONRequestRaw(_ stitchReq: StitchDocRequest) throws -> Response {
        return try doRequest(StitchRequestBuilderImpl { builder in
            builder.body = try? BSONEncoder().encode(stitchReq.document,
                                                      shouldIncludeSourceMap: false)
            builder.headers = [
                Headers.contentType.rawValue: ContentTypes.applicationJson.rawValue
            ]
            builder.path = stitchReq.path
            builder.method = stitchReq.method
        }.build())
    }

    /**
     * Builds a plain HTTP request out of the provided `StitchRequest` object.
     */
    private func buildRequest<R>(_ stitchReq: R) throws -> Request where R: StitchRequest {
        return try RequestBuilder { builder in
            builder.method = stitchReq.method
            builder.url = "\(self.baseURL)\(stitchReq.path)"
            builder.headers = stitchReq.headers
            builder.body = stitchReq.body
        }.build()
    }
}
