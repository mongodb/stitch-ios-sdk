import Foundation
import Alamofire

/// Network Adapter implementation using the `AlamoFire` framework.
public class AlamofireNetworkAdapter: NetworkAdapter {
    static var jsonArrayKey: String = "jsonArrayKey"
    public init() {}
    /**
     Make a network request with an array of key value pairs.
     
     - Parameters:
         - url: Resource to call
         - method: HTTP verb to use with this call
         - parameters: Array of key value pairs to send upstream
         - headers: Array of key value pairs to send as headers
     
     - Returns: A new `StitchTask`
     */
    public func requestWithArray(url: String, method: NAHTTPMethod, parameters: [[String : Any]]?, headers: [String : String]?) ->  StitchTask<Any> {
        let task = StitchTask<Any>()
        
        let httpMethod = httpMehod(method: method)
        let parametersForAlamoFire = parameters != nil ? [AlamofireNetworkAdapter.jsonArrayKey : parameters!] : nil
        Alamofire.request(url, method: httpMethod, parameters: parametersForAlamoFire, encoding: JSONArrayEncoding(), headers: headers)
            .responseJSON(queue: DispatchQueue.global(qos: .utility)) { [weak self] (response) in
                guard self != nil else {
                    task.result = StitchResult.failure(StitchError.clientReleased)
                    return
                }
                
                switch response.result {
                case .success(let value):
                    task.result = StitchResult.success(value)
                case .failure(let error):
                    task.result = StitchResult.failure(error)
                }
        }
        return task
    }
    /**
     Make a network request using Json encoding for the params.
     
     - Parameters:
         - url: Resource to call
         - method: HTTP verb to use with this call
         - parameters: JsonEncoded parameters as a dictionary
         - headers: Array of key value pairs to send as headers
     
     - Returns: A new `StitchTask`
     */
    public func requestWithJsonEncoding(url: String, method: NAHTTPMethod, parameters: [String : Any]?, headers: [String : String]?) -> StitchTask<Any> {
        let task = StitchTask<Any>()
        
        let httpMethod = httpMehod(method: method)
        Alamofire.request(url, method: httpMethod, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseJSON(queue: DispatchQueue.global(qos: .utility)) { [weak self] (response) in
                guard self != nil else {
                    task.result = StitchResult.failure(StitchError.clientReleased)
                    return
                }
                
                switch response.result {
                case .success(let value):
                    task.result = StitchResult.success(value)
                case .failure(let error):
                    task.result = StitchResult.failure(error)
                }
        }
        return task

    }
    
    /**
     Cancel all active requests.
     */
    public func cancelAllRequests() {
        Alamofire.SessionManager.default.session.getAllTasks { (tasks) in
            tasks.forEach{$0.cancel()}
        }
    }
    
    
    // MARK: - Parameter encoding
    
    /// A helper structure to encode the request parameters into a JSON array.
    struct JSONArrayEncoding: ParameterEncoding {
        
        private let options: JSONSerialization.WritingOptions
        
        init(options: JSONSerialization.WritingOptions = []) {
            self.options = options
        }
        
        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var urlRequest = try urlRequest.asURLRequest()
            
            guard let parameters = parameters,
                let array = parameters[jsonArrayKey] else {
                    return urlRequest
            }
            
            do {
                let data = try JSONSerialization.data(withJSONObject: array, options: options)
                
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                
                urlRequest.httpBody = data
                
            } catch {
                throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
            }
            
            return urlRequest
        }
    }
    
    //MARK: NAHTTPmethod to Alamofire
    fileprivate func httpMehod(method: NAHTTPMethod) -> HTTPMethod {
        switch method {
        case .connect:
            return HTTPMethod.connect
        case .delete:
            return HTTPMethod.delete
        case .get:
            return HTTPMethod.get
        case .head:
            return HTTPMethod.head
        case .options:
            return HTTPMethod.options
        case .patch:
            return HTTPMethod.patch
        case .post:
            return HTTPMethod.post
        case .put:
            return HTTPMethod.put
        case .trace:
            return HTTPMethod.trace
        }
    }
}
