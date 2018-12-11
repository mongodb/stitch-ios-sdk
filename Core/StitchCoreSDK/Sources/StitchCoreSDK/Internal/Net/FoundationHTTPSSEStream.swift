import Foundation

internal class FoundationURLSessionDataDelegate: NSObject, URLSessionDataDelegate {
    fileprivate weak var stream: FoundationHTTPSSEStream?
    fileprivate weak var session: URLSession?

    fileprivate init(_ stream: FoundationHTTPSSEStream) {
        self.stream = stream
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        stream?.dataBuffer.append(data)
        stream?.dispatchEvents()
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        stream?.state = .closed
    }

    private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stream?.state = .closed
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if httpResponse.statusCode == 200 {
            stream?.state = .open
        }

        if httpResponse.statusCode == 204 {
            stream?.state = .closed
        }

        self.session = session
    }
}

public class FoundationHTTPSSEStream: RawSSEStream {
    internal lazy var dataDelegate = FoundationURLSessionDataDelegate(self)

    public override func close() {
        if let session = dataDelegate.session {
            session.invalidateAndCancel()
        } else {
            dataDelegate.stream?.state = .closed
        }
    }
}
