import Foundation

/**
 * A simple class representing a JWT issued by the Stitch server. Only contains claims relevant to the SDK.
 */
internal final class JWT {
    /**
     * Per RFC 7519:
     * 4.1.4.  "exp" (Expiration Time) Claim
     *
     * The "exp" (expiration time) claim identifies the expiration time on
     * or after which the JWT MUST NOT be accepted for processing.  The
     * processing of the "exp" claim requires that the current date/time
     * MUST be before the expiration date/time listed in the "exp" claim.
     */
    public let expires: TimeInterval?

    /**
     * Per RFC 7519:
     * 4.1.6.  "iat" (Issued At) Claim
     
     * The "iat" (issued at) claim identifies the time at which the JWT was
     * issued.  This claim can be used to determine the age of the JWT.  Its
     * value MUST be a number containing a NumericDate value.  Use of this
     * claim is OPTIONAL.
     */
    public let issuedAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case expires = "exp"
        case issuedAt = "iat"
    }

    /**
     * The class of errors that may occur when initializing a JWT object.
     */
    public enum MalformedJWTError: Error {
        case shouldHaveThreeParts
        case couldNotDecodeBase64
        case couldNotParseJSON
    }

    /**
     * Initializes the `StitchJWT` with a base64-encoded string, with or without padding characters.
     */
    init(fromEncodedJWT encodedJWT: String) throws {
        let parts = try JWT.splitToken(jwt: encodedJWT)

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

    /**
     * Private utility function to split the JWT into its three constituent parts.
     */
    private static func splitToken(jwt: String) throws -> [String.SubSequence] {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw MalformedJWTError.shouldHaveThreeParts
        }

        return parts
    }
}
