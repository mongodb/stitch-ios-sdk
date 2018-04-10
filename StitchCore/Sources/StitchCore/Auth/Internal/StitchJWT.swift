import Foundation

internal final class StitchJWT {
    public let expires: Int64
    public let issuedAt: Int64

    enum CodingKeys: String, CodingKey {
        case expires = "exp"
        case issuedAt = "iat"
    }

    public enum MalformedJWTError: Error {
        case shouldHaveThreeParts
        case couldNotDecodeBase64
        case couldNotParseJSON
        case missingExpiration
        case missingIssuedAt
    }

    init(fromEncodedJWT encodedJWT: String) throws {
        let parts = try StitchJWT.splitToken(jwt: encodedJWT)

        guard let firstPart = parts.first else {
            throw MalformedJWTError.shouldHaveThreeParts
        }

        guard let json = Data.init(base64Encoded: String(firstPart)) else {
            throw MalformedJWTError.couldNotDecodeBase64
        }

        guard let token = ((try? JSONSerialization.jsonObject(with: json)) as? [String: Any]) else {
            throw MalformedJWTError.couldNotParseJSON
        }

        guard let expires = token[CodingKeys.expires.stringValue] as? Int64 else {
            throw MalformedJWTError.missingExpiration
        }

        guard let issuedAt = token[CodingKeys.issuedAt.stringValue] as? Int64 else {
            throw MalformedJWTError.missingIssuedAt
        }

        self.expires = expires
        self.issuedAt = issuedAt
    }

    private static func splitToken(jwt: String) throws -> [String.SubSequence] {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw MalformedJWTError.shouldHaveThreeParts
        }

        return parts
    }
}
