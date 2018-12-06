import Foundation

public class FoundationHTTPSSEStream<T: RawSSE>: NSObject, RawSSEStream, URLSessionDataDelegate {
    public weak var delegate: SSEStreamDelegate<T>?

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
        // TODO: close
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print(dataTask)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        print(streamTask)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        print(dataTask)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print(totalBytesSent)
    }

    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        print("hi")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        print(task)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        print(request)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print(task)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var data = data
        self.dispatchEvents(from: &data)
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print(error)
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("uh")
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("challenge")
    }

    private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            NSLog("task error: %@ / %d", error.domain, error.code)
        } else {
            NSLog("task complete")
        }
    }

    var dataTask: URLSessionDataTask?
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
