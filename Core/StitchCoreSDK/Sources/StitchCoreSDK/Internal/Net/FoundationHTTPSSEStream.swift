import Foundation

internal class FoundationURLSessionDataDelegate: NSObject, URLSessionDataDelegate {
    fileprivate weak var stream: FoundationHTTPSSEStream?
    fileprivate weak var session: URLSession?
    fileprivate var fulfillClose: Bool = false

    fileprivate init(_ stream: FoundationHTTPSSEStream) {
        self.stream = stream
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        stream?.dataBuffer.append(data)
        stream?.dispatchEvents()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        fatalError()
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
        guard let httpResponse = response as? HTTPURLResponse,
            !fulfillClose else {
            fulfillClose = false
            return
        }

        if httpResponse.statusCode == 200 {
            stream?.state = .open
        }

        if httpResponse.statusCode == 204 {
            stream?.state = .closed
        }

        self.session = session

        // store this initial response from the server
        self.stream?.initialResponse = Response.init(
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
            body: nil
        )
    }
}

public class FoundationHTTPSSEStream: RawSSEStream {
    // The reason we are disabling `weak_delegate` here is because
    // this isn't a typical delegate pattern. There's no risk of
    // a reference cycle as we want to retain this delegate as long
    // as the stream is retained. When the stream is deallocated,
    // the delegate will also be.
    // swiftlint:disable:next weak_delegate
    internal lazy var dataDelegate: FoundationURLSessionDataDelegate? = FoundationURLSessionDataDelegate(self)

    // The initial response from the Stitch server indicating whether or not the stream was successfully opened.
    // Will be 'nil' until the request is completed.
    internal var initialResponse: Response?

    public override func close() {
        dataDelegate?.stream?.state = .closing
        if let session = dataDelegate?.session {
            session.invalidateAndCancel()
        }

        // the session may not have begun yet.
        // we must still fulfill a close if called
        dataDelegate?.stream?.state = .closed
        dataDelegate = nil
    }
}
