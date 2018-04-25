import Foundation

/// For creating or updating a function of an application
public struct FunctionCreator: Encodable {
    enum CodingKeys: String, CodingKey {
        case name, source, canEvaluate = "can_evaluate", isPrivate = "private"
    }
    
    public init(name: String, source: String, canEvaluate: String?, isPrivate: Bool) {
        self.name = name
        self.source = source
        self.canEvaluate = canEvaluate
        self.isPrivate = isPrivate
    }

    let name: String
    let source: String
    let canEvaluate: String?
    let isPrivate: Bool
}

/// View of a function of an application
public struct FunctionResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "_id", name
    }
    
    /// id of the function
    public var id: String?
    
    /// name of the function
    public var name: String?
}

extension Apps.App.Functions {
    /// GET a user of an application
    /// - parameter uid: id of the user
    public func function(fid: String) -> Apps.App.Functions.Function {
        return Function.init(adminAuth: adminAuth,
                             url: "\(url)/\(fid)")
    }
}
