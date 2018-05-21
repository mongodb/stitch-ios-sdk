import BSON

/**
 * A class providing the core functionality necessary to make authenticated function call requests for a particular
 * Stitch service.
 */
public protocol CoreStitchService {
    func callFunctionInternal(withName name: String, withArgs args: [BsonValue]) throws
    
    func callFunctionInternal<T: Codable>(withName name: String, withArgs args: [BsonValue]) throws -> T
}
