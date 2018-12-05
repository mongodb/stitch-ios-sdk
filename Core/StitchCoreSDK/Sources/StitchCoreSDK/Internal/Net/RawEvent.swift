import Foundation
import MongoSwift

let messageEvent = "message"
open class RawSSE {
    public let rawData: String

    public let eventName: String

    public init?(rawData: String,
                 eventName: String) throws {
        self.rawData = rawData
        if eventName.isEmpty {
            self.eventName = messageEvent
        } else {
            self.eventName = eventName
        }
    }
}


/// Stitch event name for error messages
private let errorEventName = "error"

/// Stitch abstraction of server-sent events.
public class SSE<T: Decodable>: RawSSE {

    /// Decoded data from the event
    public var data: T? = nil

    /// Error from the event
    public var error: StitchError? = nil

    public override init?(rawData: String,
                          eventName: String) throws {
        try super.init(rawData: rawData, eventName: eventName)
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
                default: break
                }
            default: break
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
                self.error = StitchError.serviceError(withMessage: error.error,
                                                      withServiceErrorCode: error.errorCode)
            } catch {
                self.error = StitchError.serviceError(withMessage: decodedData,
                                                      withServiceErrorCode: .unknown)
            }
        case messageEvent:
            self.data = try BSONDecoder().decode(T.self,
                                                 from: decodedData.data(using: .utf8) ?? Data())
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
