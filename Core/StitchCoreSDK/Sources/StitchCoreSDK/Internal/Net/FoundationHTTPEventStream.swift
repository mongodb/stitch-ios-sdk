import Foundation

public class FoundationHTTPSSEStream: RawSSEStream {
    public lazy var delegate =
        FoundationHTTPSSEStream.FoundationURLSessionDataDelegate(self)

    public class FoundationURLSessionDataDelegate: NSObject, URLSessionDelegate {
        let rawSSEStream: RawSSEStream
        fileprivate init(_ rawSSEStream: RawSSEStream) {
            self.rawSSEStream = rawSSEStream
            super.init()
        }

        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            self.rawSSEStream.appendData(data)
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
                rawSSEStream.open()
            }

            if httpResponse.statusCode == 204 {
                rawSSEStream.close()
            }
        }
    }
}
