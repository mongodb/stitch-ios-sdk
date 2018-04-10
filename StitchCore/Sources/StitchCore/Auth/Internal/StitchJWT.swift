import Foundation

internal final class StitchJWT {
    public let expires: TimeInterval?
    public let issuedAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case expires = "exp"
        case issuedAt = "iat"
    }

    public enum MalformedJWTError: Error {
        case shouldHaveThreeParts
        case couldNotDecodeBase64
        case couldNotParseJSON
    }

    init(fromEncodedJWT encodedJWT: String) throws {
        let parts = try StitchJWT.splitToken(jwt: encodedJWT)

        var secondPart = String(parts[1])

        let extraCharacters = secondPart.count % 4
        if extraCharacters != 0 {
            secondPart = secondPart.padding(
                toLength: secondPart.count + (4 - extraCharacters),
                withPad: "=",
                startingAt: 0
            )
        }

        guard let json = Data.init(base64Encoded: secondPart) else {
            throw MalformedJWTError.couldNotDecodeBase64
        }

        guard let token = ((try? JSONSerialization.jsonObject(with: json)) as? [String: Any]) else {
            throw MalformedJWTError.couldNotParseJSON
        }

        self.expires = token[CodingKeys.expires.stringValue] as? TimeInterval
        self.issuedAt = token[CodingKeys.issuedAt.stringValue] as? TimeInterval
    }

    private static func splitToken(jwt: String) throws -> [String.SubSequence] {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw MalformedJWTError.shouldHaveThreeParts
        }

        return parts
    }
}
