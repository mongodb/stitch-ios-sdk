import Foundation

/**
 * A protocol representing an HTTP transport capable of making requests and receiving responses.
 */
public protocol Transport {
    /**
     Performs an HTTP round trip, blocking the current thread until it is completed.

     - parameter request: The HTTP request to be made.
     - returns: The response to the request.
     */
    func roundTrip(request: Request) throws -> Response

    /**
     Opens an HTTP SSE stream.

     - parameter request: The HTTP request to open the stream.
     - parameter delegate: The stream delegate that will react to incoming events from the stream.
     - returns: The raw SSE stream object
     */
    func stream(request: Request, delegate: SSEStreamDelegate?) throws -> RawSSEStream
}
