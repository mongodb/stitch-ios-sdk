import Foundation

/**
 * Represents a RFC 6265 cookie.
 */
public struct HTTPCookie {
    internal enum CodingKeys: String, CodingKey {
        case value, path, domain, expires, maxAge, secure, httpOnly
    }
    
    /**
     * The name of the cookie.
     */
    public let name: String
    
    /**
     * The value of the cookie.
     */
    public let value: String
    
    /**
     * The path within the domain to which this cookie belongs.
     */
    public let path: String?
    
    /**
     * The domain to which this cookie belongs.
     */
    public let domain: String?
    
    /**
     * When the cookie expires
     */
    public let expires: String?
    
    /**
     * How long the cookie can live for.
     */
    public let maxAge: String?
    
    /**
     * Whether or not this cookie can only be sent to HTTPS servers.
     */
    public let secure: Bool?
    
    /**
     * Whether or not this cookie can only be read by a server.
     */
    public let httpOnly: Bool?
}
