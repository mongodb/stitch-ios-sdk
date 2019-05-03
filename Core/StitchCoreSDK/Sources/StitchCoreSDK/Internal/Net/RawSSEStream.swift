import Foundation
import MongoSwift

private let newlineChar = [UInt8]("\n".utf8)[0]

public enum SSEStreamState {
    case opening, open, closing, closed
}

open class SSEStreamDelegate: Hashable {
    public static func == (lhs: SSEStreamDelegate, rhs: SSEStreamDelegate) -> Bool {
        return lhs === rhs
    }

    public init() {}

    open func on(newEvent event: RawSSE) {

    }

    open func on(stateChangedFor state: SSEStreamState) {

    }

    open func on(error: Error) {

    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

open class RawSSEStream {
    private let queue = DispatchQueue.init(label: "sse-\(ObjectId().hex)")
    open var state: SSEStreamState = .closed {
        didSet {
            self.delegate?.on(stateChangedFor: self.state)
        }
    }

    public weak var delegate: SSEStreamDelegate?
    public var dataBuffer = Data()

    private var stringBuffer: String = ""
    private var eventNameBuffer: String = ""

    public init(_ delegate: SSEStreamDelegate? = nil) {
        self.delegate = delegate
    }

    open func open() {

    }

    open func close() {

    }

    /**
     Read the next line of a stream from a given source.
     - returns: the next utf8 line
     */
    private func readLine() -> String? {
        guard let newlineIndex = self.dataBuffer.firstIndex(of: newlineChar) else {
            return nil
        }

        let line = self.dataBuffer[dataBuffer.startIndex ..< newlineIndex]
        self.dataBuffer.removeSubrange(dataBuffer.startIndex ..< newlineIndex + 1)
        return String.init(data: line, encoding: .utf8)
    }

    private func process(value: String,
                         forField field: String) {
        // If the field name is "event"
        switch field {
        case "event":
            eventNameBuffer = value
        // If the field name is "data"
        case "data":
            // If the data buffer is not the empty string, then append a single U+000A LINE FEED
            // character to the data buffer.
            stringBuffer += value
            if dataBuffer.count != 0 {
                stringBuffer += "\n"
            }
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
     Process and dispatch the events in a given stream.
     */
    internal func dispatchEvents() {
        while state == .open, let line = self.readLine() {
            // If the line is empty (a blank line), Dispatch the event, as defined below.
            if line.isEmpty {
                // If the data buffer is an empty string, set the data buffer and the event name buffer to
                // the empty string and abort these steps.
                if stringBuffer.count == 0 {
                    eventNameBuffer = ""
                    continue
                }

                // If the event name buffer is not the empty string but is also not a valid NCName,
                // set the data buffer and the event name buffer to the empty string and abort these steps.
                // NOT IMPLEMENTED
                do {
                    guard let sse = try RawSSE.init(
                        rawData: String(stringBuffer.dropLast()), eventName: eventNameBuffer
                    ) else {
                        continue
                    }

                    queue.async {
                        self.delegate?.on(newEvent: sse)
                    }
                    stringBuffer = ""
                    eventNameBuffer = ""
                } catch {
                    delegate?.on(error: error)
                    return
                }
                // If the line starts with a U+003A COLON character (':')
            } else if line.starts(with: ":") {
                // ignore the line
                // If the line contains a U+003A COLON character (':') character
            } else if line.contains(":") {
                // Collect the characters on the line before the first U+003A COLON character (':'),
                // and let field be that string.
                let colonIdx = line.firstIndex(of: ":")!
                let field = line[line.startIndex ..< colonIdx]

                // Collect the characters on the line after the first U+003A COLON character (':'),
                // and let value be that string.
                // If value starts with a single U+0020 SPACE character, remove it from value.
                var value = line[line.index(after: colonIdx) ..< line.endIndex]
                value = value.starts(with: " ") ? value.dropFirst() : value

                process(value: String(value), forField: String(field))
                // Otherwise, the string is not empty but does not contain a U+003A COLON character (':')
                // character
            } else {
                process(value: "", forField: line)
            }
        }
    }
}
