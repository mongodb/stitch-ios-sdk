/// HTTP Header definitions and helper methods.
public enum Headers: String {
    case contentType = "Content-Type"
    case authorization = "Authorization"
    case bearer = "Bearer"

    public static func authorizationBearer(forValue value: String) -> String {
        return "\(Headers.bearer.rawValue) \(value)"
    }
}
