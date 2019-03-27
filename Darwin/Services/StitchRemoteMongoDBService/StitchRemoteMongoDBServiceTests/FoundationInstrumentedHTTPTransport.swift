import Foundation
import MongoSwift
@testable import StitchCoreSDK

/**
 * A basic implementation of the `Transport` protocol using the `URLSession.dataTask` method in the Foundation library.
 */
public class FoundationInstrumentedHTTPTransport: FoundationHTTPTransport {
    private var bytesUploadedForNormalRequests: Int64 = 0
    private var bytesDownloadedForNormalRequests: Int64 = 0

    private var streamTasks: [URLSessionDataTask] = []
    private var rawStreams: [FoundationHTTPSSEStream] = []

    /**
     * Returns the number of bytes uploaded by this transport via HTTP request body and HTTP request headers. This
     * figure does not include HTTP protocol overhead, or other low-level overhead at or below the TCP level.
     */
    public var bytesUploaded: Int64 {
        var bytesUploadedForStreamRequests: Int64 = 0

        self.streamTasks.forEach { task in
            bytesUploadedForStreamRequests += task.countOfBytesSent
        }

        return bytesUploadedForStreamRequests + self.bytesUploadedForNormalRequests
    }

    /**
     * Returns the number of bytes downloaded by this transport via HTTP request body and HTTP request headers. This
     * figure does not include HTTP protocol overhead, or other low-level overhead at or below the TCP level.
     */
    public var bytesDownloaded: Int64 {
        var bytesDownloadedForStreamRequests: Int64 = 0

        self.streamTasks.forEach { task in
            bytesDownloadedForStreamRequests += task.countOfBytesReceived
        }
        self.rawStreams.forEach { stream in
            if let initialResponse = stream.initialResponse {
                bytesDownloadedForStreamRequests += estimatedHeaderBytes(forResponse: initialResponse)
            }
        }

        return bytesDownloadedForStreamRequests + self.bytesDownloadedForNormalRequests
    }

    /**
     * The round trip functionality for this Transport, which uses `URLSession.dataTask`, and tracks the
     * network usage of the request.
     */
    public override func roundTrip(request: Request) throws -> Response {
        let (response, task) = try self.doRoundTrip(request: request)

        self.bytesDownloadedForNormalRequests +=
            task.countOfBytesReceived + estimatedHeaderBytes(forResponse: response)
        self.bytesUploadedForNormalRequests +=
            task.countOfBytesSent + estimatedHeaderBytes(forRequest: request)

        return response
    }

    /**
     * The stream functionality for this Transport, which uses `URLSession.dataTask`, and tracks the
     * network usage of the stream.
     */
    public override func stream(request: Request, delegate: SSEStreamDelegate? = nil) throws -> RawSSEStream {
        let (rawStream, task) = try self.doStream(request: request, delegate: delegate)

        self.bytesUploadedForNormalRequests += task.countOfBytesSent + estimatedHeaderBytes(forRequest: request)

        self.streamTasks.append(task)

        // we know this will be a FoundationHTTPSSEStream because we're subclassing a FoundationHTTPTransport
        // swiftlint:disable force_cast
        self.rawStreams.append(rawStream as! FoundationHTTPSSEStream)
        // swiftlint:enable force_cast
        return rawStream
    }

    /**
     * Determines the number of bytes necessary to encode the pre-body headers for the provided HTTP request.
     * This is necessary because Foundation's HTTP library does not track bytes that are not part of the HTTP body.
     * Does not include low-level overhead such as TLS handshake or headers appended by iOS.
     */
    private func estimatedHeaderBytes(forRequest request: Request) -> Int64 {
        var result: Int64 = 0

        // Count the bytes for the Request-Line
        // see: (https://www.w3.org/Protocols/HTTP/1.1/rfc2616bis/draft-lafon-rfc2616bis-03.html#request-line)
        result += Int64("\(request.method.rawValue) \(request.url) HTTP/1.1\r\n".count)

        // Each header 2 bytes of overhead for ': ' and 2 bytes for CRLF.
        result += (Int64(request.headers.count) * (2 + 2))

        // The headers themselves need to be encoded
        request.headers.forEach { (key, value) in
            result += (Int64(key.count + value.count))
        }

        // A CRLF separates the pre-body headers and the body itself
        result += 2

        return result
    }

    private func estimatedHeaderBytes(forResponse response: Response) -> Int64 {
        var result: Int64 = 0

        // Estimate the bytes for the Status-Line
        // see: (https://www.w3.org/Protocols/HTTP/1.1/rfc2616bis/draft-lafon-rfc2616bis-03.html#status-line)
        // This is an estimate because we do not have access to the reason phrase, which is typically under 20 bytes,
        // so for estimation's sake we'll always use 'OK', which is the reason phrase for HTTP 200.
        result += Int64("HTTP/1.1 \(response.statusCode) OK\r\n".count)

        // Each header 2 bytes of overhead for ': ' and 2 bytes for CRLF.
        result += (Int64(response.headers.count) * (2 + 2))

        // The headers themselves need to be encoded
        response.headers.forEach { (key, value) in
            result += (Int64(key.count + value.count))
        }

        // A CRLF separates the pre-body headers and the body itself
        result += 2

        return result
    }
}
