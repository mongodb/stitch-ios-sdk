import Foundation

public class FoundationHTTPSSEStream<T: RawSSE>: RawSSEStream {
    public var delegate: SSEStreamDelegate<T>?

    private var _state: SSEStreamState = .closed
    public private(set) var state: SSEStreamState {
        get {
            return _state
        }
        set {
            _state = newValue
            delegate?.on(stateChangedFor: _state)
        }
    }

    public typealias SSEType = T

    private var data = Data()

    public lazy var urlSessionDelegate =
        FoundationHTTPSSEStream.FoundationURLSessionDataDelegate(self)

    public class FoundationURLSessionDataDelegate: NSObject, URLSessionDelegate {
        let rawSSEStream: FoundationHTTPSSEStream
        fileprivate init(_ foundationHTTPStream: FoundationHTTPSSEStream) {
            self.rawSSEStream = foundationHTTPStream
            super.init()
        }

        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            var data = data
            self.rawSSEStream.dispatchEvents(from: &data)
        }

        private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error as NSError? {
                NSLog("task error: %@ / %d", error.domain, error.code)
            } else {
                NSLog("task complete")
            }
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
                rawSSEStream.state = .open
            }

            if httpResponse.statusCode == 204 {
                rawSSEStream.state = .closed
            }
        }
    }

    public func open() {
        // open by default
    }

    public func close() {
        // TODO: close
    }
}
