import Foundation

internal let newlineChar = [UInt8]("\n".utf8)[0]

public enum SSEStreamState {
    case open, closed
}

open class SSEStreamDelegate<SSEType: RawSSE> {
    public init() {}
    
    open func on(newEvent event: SSEType) {

    }

    open func on(stateChangedFor state: SSEStreamState) {

    }

    open func on(error: Error) {

    }
}

public protocol RawSSEStream {
    associatedtype SSEType: RawSSE

    var delegate: SSEStreamDelegate<SSEType>? { get set }
    var state: SSEStreamState { get }

    func open()
    func close()
}

public class AnyRawSSEStream<T: RawSSE>: RawSSEStream {
    private let _state: () -> SSEStreamState
    private let _open: () -> ()
    private let _close: () -> ()
    private let _delegate_get: () -> SSEStreamDelegate<T>?
    private let _delegate_set: (SSEStreamDelegate<T>?) -> ()

    public typealias SSEType = T

    public init<U: RawSSEStream>(_ rawSSEStream: inout U) where U.SSEType == T {
        var rawRef = rawSSEStream
        self._state = { rawRef.state }
        self._open = rawRef.open
        self._close = rawRef.close

        self._delegate_get = {
            rawRef.delegate
        }
        self._delegate_set = {
            rawRef.delegate = $0
        }
    }

    public var delegate: SSEStreamDelegate<T>? {
        get {
            return self._delegate_get()
        }
        set {
            self._delegate_set(newValue)
        }
    }

    public var state: SSEStreamState {
        return _state()
    }

    public func open() {
        _open()
    }

    public func close() {
        _close()
    }
}

extension RawSSEStream {
    /**
     Read the next line of a stream from a given source.
     - returns: the next utf8 line
     */
    private func readLine(from data: inout Data) -> String? {
        guard let newlineIndex = data.firstIndex(of: newlineChar) else {
            let line = String.init(data: data, encoding: .utf8)!
            data.removeAll()
            return line
        }

        let line = data[data.startIndex ..< newlineIndex]
        data.removeSubrange(data.startIndex ..< newlineIndex + 1)
        return String.init(data: line, encoding: .utf8)
    }

    private func process(value: String,
                         forField field: String,
                         eventName: inout String,
                         dataBuffer: inout String) {
        // If the field name is "event"
        switch (field) {
        case "event":
            eventName = value
            break
        // If the field name is "data"
        case "data":
            // If the data buffer is not the empty string, then append a single U+000A LINE FEED
            // character to the data buffer.
            if dataBuffer.count != 0 {
                dataBuffer += "\n"
            }
            dataBuffer += value
            break
        // If the field name is "id"
        case "id":
            // NOT IMPLEMENTED
            break
        // If the field name is "retry"
        case "retry":
            // NOT IMPLEMENTED
            break
        // Otherwise
        default:
            // The field is ignored.
            break
        }
    }

    /**
     Process the next event in a given stream.
     - returns: the fully processed event
     */
    internal func dispatchEvents(from data: inout Data) {
        var dataBuffer = ""
        var eventName = ""
        while state == .open, let line = self.readLine(from: &data) {
            // If the line is empty (a blank line), Dispatch the event, as defined below.
            if line.isEmpty || line == "\n" {
                // If the data buffer is an empty string, set the data buffer and the event name buffer to
                // the empty string and abort these steps.
                if (dataBuffer.count == 0) {
                    eventName = ""
                    continue
                }

                // If the event name buffer is not the empty string but is also not a valid NCName,
                // set the data buffer and the event name buffer to the empty string and abort these steps.
                // NOT IMPLEMENTED
                do {
                    guard let sse = try SSEType.init(rawData: dataBuffer, eventName: eventName) else {
                        continue
                    }

                    delegate?.on(newEvent: sse)
                } catch {
                    delegate?.on(error: error)
                    return
                }
            // If the line starts with a U+003A COLON character (':')
            } else if line.starts(with: ":") {
                // ignore the line
                // If the line contains a U+003A COLON character (':') character
            } else if line.contains(":") {
                print(line)
                // Collect the characters on the line before the first U+003A COLON character (':'),
                // and let field be that string.
                let colonIdx = line.firstIndex(of: ":")!
                let field = line[line.startIndex ..< colonIdx]

                // Collect the characters on the line after the first U+003A COLON character (':'),
                // and let value be that string.
                // If value starts with a single U+0020 SPACE character, remove it from value.
                var value = line[line.index(after: colonIdx) ..< line.endIndex]
                value = value.starts(with: " ") ? value.dropFirst() : value

                process(value: String(value), forField: String(field), eventName: &eventName, dataBuffer: &dataBuffer)
                // Otherwise, the string is not empty but does not contain a U+003A COLON character (':')
                // character
            } else {
                process(value: "", forField: line, eventName: &eventName, dataBuffer: &dataBuffer)
            }
        }
    }
}
