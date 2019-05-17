import Foundation
import MongoSwift

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
     * The base URL of the Stitch server to which this client will retrieve metadata.
     */
    var baseURL: String { get }

    /**
     * The `Transport` which this client will use to make round trips to the Stitch server.
     */
    var transport: Transport { get }

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout should override this one.
     */
    var defaultRequestTimeout: TimeInterval { get }

    /**
     * Performs a request against the Stitch server with the given `StitchRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    func doRequest(_ stitchReq: StitchRequest) throws -> Response

    /**
     Requests that a new stream be open against the Stitch server

     - returns: a new stream
    */
    func doStreamRequest(_ stitchReq: StitchRequest, delegate: SSEStreamDelegate?) throws -> RawSSEStream
}

extension StitchRequestClient {
    func doRequest(_ stitchReq: StitchRequest, url: String) throws -> Response {
        var response: Response!
        do {
            response = try self.transport.roundTrip(request: self.buildRequest(stitchReq, url: url))
        } catch {
            // Wrap the error from the transport in a `StitchError.requestError`
            throw StitchError.requestError(withError: error, withRequestErrorCode: .transportError)
        }
        return try inspectResponse(response: response)
    }

    public func doStreamRequest(
        _ stitchReq: StitchRequest,
        url: String,
        delegate: SSEStreamDelegate? = nil
    ) throws -> RawSSEStream {
        do {
            return try transport.stream(request: buildRequest(stitchReq, url: url), delegate: delegate)
        } catch {
            guard let err = error as? StitchError else {
                throw StitchError.requestError(withError: error, withRequestErrorCode: .transportError)
            }
            throw err
        }
    }

    /**
     * Builds a plain HTTP request out of the provided `StitchRequest` object.
     */
    private func buildRequest(_ stitchReq: StitchRequest, url: String) throws -> Request {
        let reqBuilder = RequestBuilder()
            .with(method: stitchReq.method)
            .with(url: "\(url)\(stitchReq.path)")
            .with(timeout: stitchReq.timeout ?? self.defaultRequestTimeout)
            .with(headers: stitchReq.headers)
            .with(body: stitchReq.body)

        return try reqBuilder.build()
    }
}

/**
 * An implementation of `StitchRequestClient` that builds on `StitchRequestClientImpl` to
 * add the ability to use a client application ID to target location-specific endpoints.
 */
public class StitchAppRequestClientImpl: StitchRequestClient {
    /**
     * The base URL of the Stitch server to which this client will retrieve metadata.
     */
    public let baseURL: String

    /**
     * The `Transport` which this client will use to make round trips to the Stitch server.
     */
    public let transport: Transport

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout should override this one.
     */
    public let defaultRequestTimeout: TimeInterval

    /**
     * The client application ID for the application.
     */
    private let clientAppId: String

    /**
     * Route constants used to path requests properly.
     */
    private let appRoutes: StitchAppRoutes

    /**
     * The application metadata as discovered by communicating with the server.
     */
    private var appMetadata: AppMetadata?

    /**
     * Initializes the request client with the provided client app ID, base URL and `Transport`.
     */
    public init(clientAppId: String, baseURL: String, transport: Transport,
                defaultRequestTimeout: TimeInterval) {
        self.clientAppId = clientAppId
        self.baseURL = baseURL
        self.transport = transport
        self.defaultRequestTimeout = defaultRequestTimeout
        self.appRoutes = StitchAppRoutes.init(clientAppID: clientAppId)
    }

    /**
     * Performs a request against the Stitch server with the given `StitchRequest` object. Uses
     * the local stitch hostname provided by the server instead of the base URL.
     *
     * - returns: the response to the request as a `Response` object.
     */
    public func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        try self.initAppMetadata()
        return try doRequest(stitchReq, url: self.appMetadata!.hostname)
    }

    public func doStreamRequest(_ stitchReq: StitchRequest, delegate: SSEStreamDelegate? = nil) throws -> RawSSEStream {
        try self.initAppMetadata()
        return try doStreamRequest(stitchReq, url: self.appMetadata!.hostname, delegate: delegate)
    }

    func initAppMetadata() throws {
        guard appMetadata == nil else {
            return
        }

        let req = StitchRequest.init(path: self.appRoutes.serviceRoutes.appMetadataRoute,
                                     method: Method.get, headers: [:],
                                     timeout: self.defaultRequestTimeout, body: nil)

        let decoder = JSONDecoder()
        do {
            let response = try doRequest(req, url: self.baseURL)
            guard let body = response.body else {
                throw StitchError.requestError(
                    withError: RuntimeError.internalError(message: "empty body in location metadata"),
                     withRequestErrorCode: .decodingError)
            }
            self.appMetadata = try decoder.decode(AppMetadata.self, from: body)
        } catch {
            // Wrap the error from the transport in a `StitchError.requestError`
            throw StitchError.requestError(withError: error,
                                           withRequestErrorCode: .transportError)
        }
    }
}

/**
 * The implementation of `StitchRequestClient`.
 */
public class StitchRequestClientImpl: StitchRequestClient {
    /**
     * The base URL of the Stitch server to which this client will make requests.
     */
    public let baseURL: String

    /**
     * The `Transport` which this client will use to make round trips to the Stitch server.
     */
    public let transport: Transport

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout should override this one.
     */
    public let defaultRequestTimeout: TimeInterval

    /**
     * Initializes the request client with the provided base URL and `Transport`.
     */
    public required init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) {
        self.baseURL = baseURL
        self.transport = transport
        self.defaultRequestTimeout = defaultRequestTimeout
    }

    /**
     * Performs a request against the Stitch server with the given `StitchRequest` object.
     *
     * - returns: the response to the request as a `Response` object.
     */
    public func doRequest(_ stitchReq: StitchRequest) throws -> Response {
        return try doRequest(stitchReq, url: self.baseURL)
    }

    public func doStreamRequest(_ stitchReq: StitchRequest, delegate: SSEStreamDelegate?) throws -> RawSSEStream {
        return try doStreamRequest(stitchReq, url: self.baseURL, delegate: delegate)
    }
}
