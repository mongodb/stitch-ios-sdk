/**
 * :nodoc:
 * A client for the server API key authentication provider which can be used to obtain a credential for logging in.
 */
public final class ServerApiKeyAuthProvider {
    private init() {}
    
    public static let type = "api-key"
    public static let defaultName = "api-key"
}
