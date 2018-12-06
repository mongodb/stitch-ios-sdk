import Foundation

public class FoundationHTTPSSEStream<T: RawSSE>: NSObject, RawSSEStream, URLSessionDataDelegate {
    public weak var delegate: SSEStreamDelegate<T>?
    private weak var dataTask: URLSessionDataTask?

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

    public func open() {
        // open by default
    }

    public func close() {
        dataTask?.cancel()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var data = data
        self.dispatchEvents(from: &data)
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("became invalid")
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
            state = .open
        }

        if httpResponse.statusCode == 204 {
            state = .closed
        }

        self.dataTask = dataTask
    }
}
