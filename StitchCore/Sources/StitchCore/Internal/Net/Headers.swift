/// HTTP Header definitions and helper methods.
public enum Headers: String {
    case contentType = "Content-Type"
    case authorization = "Authorization"
    case bearer = "Bearer"

    /**
     * Returns an Authorization bearer header with the `forValue` parameter as the Bearer value.
     */
    public static func authorizationBearer(forValue value: String) -> String {
        return "\(Headers.bearer.rawValue) \(value)"
    }
}
