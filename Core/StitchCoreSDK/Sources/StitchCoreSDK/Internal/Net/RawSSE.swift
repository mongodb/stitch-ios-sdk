import Foundation
import MongoSwift

/// Default message name
private let messageEvent = "message"
/// Stitch event name for error messages
private let errorEventName = "error"

/// Stitch Error representation from within SSEs
private struct Error: Codable {
    private enum CodingKeys: String, CodingKey {
        case error = "error"
        case errorCode = "error_code"
    }

    let error: String
    let errorCode: StitchServiceErrorCode
}

/// Representation of a raw server sent event
open class RawSSE {
    /// The raw data from this event
    let rawData: String
    /// The name of this event
    let eventName: String

    required public init?(rawData: String, eventName: String) throws {
        self.rawData = rawData
        self.eventName = eventName
    }

    /*
     Decode the data from this raw SSE into the Stitch format

     - returns: the data decoded as type T
     */
    // swiftlint:disable:next cyclomatic_complexity
    public final func decodeStitchSSE<T: Decodable>() throws -> T? {
        let data = rawData
        var indices = data.indices
        var decodedData = ""

        while let chIdx = indices.popFirst() {
            let char = data[chIdx]
            switch char {
            case "%":
                let startIndex = data.index(after: chIdx)
                guard let endIndex = data.index(chIdx, offsetBy: 3,
                                                limitedBy: data.endIndex) else {
                                                    break
                }
                let code = data[startIndex ..< endIndex]
                switch code {
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
            return try BSONDecoder().decode(T.self,
                                            from: Document.init(fromJSON: decodedData))
        default: return nil
        }
    }

}
