import Foundation
import MongoSwift

public protocol RawSSE {
    var rawData: String { get }

    var eventName: String { get }

    init?(rawData: String, eventName: String) throws
}

/// Default message name
let messageEvent = "message"
/// Stitch event name for error messages
private let errorEventName = "error"

/// Stitch abstraction of server-sent events.
public final class SSE<T: Decodable>: RawSSE {
    public let rawData: String

    public let eventName: String

    /// Decoded data from the event
    public let data: T

    public init?(rawData: String, eventName: String) throws {
        self.rawData = rawData
        self.eventName = eventName
        let data = rawData
        var indices = data.indices
        var decodedData = ""

        while let chIdx = indices.popFirst() {
            let char = rawData[chIdx]
            switch char {
            case "%":
                let startIndex = data.index(after: chIdx)
                guard let endIndex = data.index(chIdx, offsetBy: 3,
                                                limitedBy: data.endIndex) else {
                                                    break
                }
                let code = data[startIndex ..< endIndex]
                switch (code) {
                case "25":
                    decodedData += "%"
                    indices.removeFirst(2)
                case "0A":
                    decodedData += "\n"
                    indices.removeFirst(2)
                case "0D":
                    decodedData += "\r"
                    indices.removeFirst(2)
                default:
                    break
                }
            default:
                decodedData.append(char)
            }
        }

        switch eventName {
        case errorEventName:
            // parse the error as json
            // if it is not valid json, parse the body as seen in
            // StitchError#handleRequestError
            do {
                let error = try JSONDecoder().decode(Error.self,
                                                     from: decodedData.data(using: .utf8) ?? Data())
                throw StitchError.serviceError(withMessage: error.error,
                                               withServiceErrorCode: error.errorCode)
            } catch {
                throw StitchError.serviceError(withMessage: decodedData,
                                               withServiceErrorCode: .unknown)
            }
        case messageEvent, "":
            self.data = try BSONDecoder().decode(T.self,
                                                 from: Document.init(fromJSON: decodedData))
        default: return nil
        }
    }

    private struct Error: Codable {
        private enum CodingKeys: String, CodingKey {
            case error = "error"
            case errorCode = "error_code"
        }

        let error: String
        let errorCode: StitchServiceErrorCode
    }
}
