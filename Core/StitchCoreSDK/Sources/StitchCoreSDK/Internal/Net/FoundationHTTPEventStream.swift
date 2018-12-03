import Foundation

public class FoundationHTTPEventStream: EventStream {
    private static let newlineChar = [UInt8]("\n".utf8)[0]

    private let inputStream: InputStream
    public var isOpen: Bool {
        return inputStream.streamStatus == .open
    }

    init(inputStream: InputStream) {
        self.inputStream = inputStream
    }

    public func close() {
        inputStream.close()
    }

    public func cancel() {
        inputStream.close()
    }

    public func readLine() -> String? {
        // Read data chunks from inputStream until a line delimiter is found:
        var data = Data()
        var nextChar: UInt8 = 0
        repeat {
            guard inputStream.read(&nextChar, maxLength: 1) > 0,
                nextChar != FoundationHTTPEventStream.newlineChar else {
                break
            }

            data.append(nextChar)
        } while inputStream.streamStatus != .atEnd
        
        return String.init(data: data, encoding: .utf8)
    }
}
