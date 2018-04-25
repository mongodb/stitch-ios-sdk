import Foundation
import ExtendedJSON

public protocol RuleActions: Encodable {}
extension RuleActions {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard (child.value as? Bool) == true,
                let label = child.label else {
                continue
            }

            try container.encode(label)
        }
    }
}

public struct RuleCreator: Encodable {
    let name: String
    let actions: RuleActionsCreator
    let when: Document = [:]
}

/// Allowed actions for an AWS SES service rule
private struct AwsSesRuleActions: RuleActions {
    let send: Bool
}

/// Allowed actions for a Twilio service rule
private struct TwilioRuleActions: RuleActions {
    let send: Bool
}

/// Allowed actions for an Http service rule
private struct HttpRuleActions: RuleActions {
    let get, post, put, delete, patch, head: Bool
}

internal enum RuleActionsCreator: Encodable {
    /// - parameter get: allow GET method
    /// - parameter post: allow POST method
    /// - parameter put: allow PUT method
    /// - parameter delete: allow DELETE method
    /// - parameter patch: allow PATCH method
    /// - parameter head: allow HEAD method
    case http(get: Bool, post: Bool, put: Bool, delete: Bool, patch: Bool, head: Bool)
    /// - parameter send: allow message sending
    case twilio(send: Bool)
    /// - parameter send: allow message sending
    case awsSes(send: Bool)

    func encode(to encoder: Encoder) throws {
        /// encode a rule to its associated wrapper
        switch self {
        case .http(let get, let post, let put, let delete, let patch, let head):
            try HttpRuleActions.init(get: get,
                                     post: post,
                                     put: put,
                                     delete: delete,
                                     patch: patch,
                                     head: head).encode(to: encoder)
        case .twilio(let send):
            try TwilioRuleActions.init(send: send).encode(to: encoder)
        case .awsSes(let send):
            try AwsSesRuleActions.init(send: send).encode(to: encoder)
        }
    }
}

public struct RuleResponse: Codable {
    init() {
        fatalError("RuleView not implemented")
    }
}
