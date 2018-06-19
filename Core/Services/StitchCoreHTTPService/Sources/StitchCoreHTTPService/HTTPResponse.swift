import Foundation
import MongoSwift

/**
 * The response to an HTTP request over the HTTP service.
 */
public struct HTTPResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case status, statusCode, contentLength, headers, cookies, body
    }
    
    /**
     * The human readable status of the response.
     */
    public let status: String
    
    /**
     * The status code of the response.
     */
    public let statusCode: Int
    
    /**
     * The content length of the response.
     */
    public let contentLength: Int64
    
    /**
     * The response headers.
     */
    public let headers: [String: [String]]?
    
    /**
     * The response cookies.
     */
    public let cookies: [String: HTTPCookie]?
    
    /**
     * The response body.
     */
    public let body: Data?
    
    internal init(status: String,
                  statusCode: Int,
                  contentLength: Int64,
                  headers: [String: [String]]?,
                  cookies: [String: HTTPCookie],
                  body: Data?) {
        self.status = status
        self.statusCode = statusCode
        self.contentLength = contentLength
        self.headers = headers
        self.cookies = cookies
        self.body = body
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.status = try container.decode(String.self, forKey: .status)
        self.statusCode = try container.decode(Int.self, forKey: .statusCode)
        self.contentLength = try container.decode(Int64.self, forKey: .contentLength)
        self.headers = try container.decodeIfPresent([String: [String]].self, forKey: .headers)
        
        if let bsonBinaryBody = try container.decodeIfPresent(Binary.self, forKey: .body) {
            self.body = bsonBinaryBody.data
        } else {
            self.body = nil
        }
        
        if let decodedCookies = try container.decodeIfPresent(Document.self, forKey: .cookies) {
            var cookies: [String: HTTPCookie] = [:]
            try decodedCookies.forEach { (key, bsonValue) in
                guard let document = bsonValue as? Document else {
                    throw MongoError.typeError(message: "unexpected cookie type in HTTP service response")
                }
                
                guard let value: String = try? document.get("value") else {
                    throw MongoError.typeError(message: "expected string value for cookie value in HTTP service response")
                }
                
                let path = document[HTTPCookie.CodingKeys.path.rawValue] as? String
                let domain = document[HTTPCookie.CodingKeys.domain.rawValue] as? String
                let expires = document[HTTPCookie.CodingKeys.expires.rawValue] as? String
                let maxAge = document[HTTPCookie.CodingKeys.maxAge.rawValue] as? String
                let secure = document[HTTPCookie.CodingKeys.secure.rawValue] as? Bool
                let httpOnly = document[HTTPCookie.CodingKeys.httpOnly.rawValue] as? Bool
                
                cookies[key] = HTTPCookie.init(
                    name: key,
                    value: value,
                    path: path,
                    domain: domain,
                    expires: expires,
                    maxAge: maxAge,
                    secure: secure,
                    httpOnly: httpOnly
                )
            }
            
            self.cookies = cookies
        } else {
            self.cookies = nil
        }
    }
}
