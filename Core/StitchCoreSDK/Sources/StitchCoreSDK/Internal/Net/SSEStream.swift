import Foundation

public class SSEStream<T: Decodable>: RawSSEStream {
    public var delegate: SSEStreamDelegate<SSE<T>>? {
        get {
            return underlyingRawStream.delegate
        } set {
            underlyingRawStream.delegate = newValue
        }
    }

    public var state: SSEStreamState {
        return underlyingRawStream.state
    }

    public typealias SSEType = SSE<T>
    
    private let underlyingRawStream: AnyRawSSEStream<SSE<T>>

    init(_ underlyingRawStream: AnyRawSSEStream<SSE<T>>) {
        self.underlyingRawStream = underlyingRawStream
    }

    public func open() {
        self.underlyingRawStream.open()
    }

    public func close() {
        self.underlyingRawStream.close()
    }
}
