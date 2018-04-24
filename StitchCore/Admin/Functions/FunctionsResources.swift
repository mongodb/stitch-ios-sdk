import Foundation

/// For creating or updating a function of an application
public struct FunctionCreator: Encodable {
    enum CodingKeys: String, CodingKey {
        case name, source, canEvaluate = "can_evaluate", isPrivate = "private"
    }

    let name: String
    let source: String
    let canEvaluate: String?
    let isPrivate: Bool
}

/// View of a User of an application
public struct FunctionResponse: Decodable {
    /// id of the user
    var id: String?
}

extension Apps.App.Functions {
    /// GET a user of an application
    /// - parameter uid: id of the user
    public func function(fid: String) -> Apps.App.Functions.Function {
        return Function.init(adminAuth: adminAuth,
                             url: "\(url)/\(fid)")
    }
}
