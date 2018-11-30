import Foundation
import MongoSwift

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

public enum RuleCreator: Encodable {
    case actions(name: String, actions: RuleActionsCreator)
    case actionsWithWhen(name: String, actions: RuleActionsCreator, when: Document)
    case mongoDb(namespace: String, rule: Document)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .actions(let name, let actions):
            try RuleCreatorActions.init(name: name, actions: actions).encode(to: encoder)
        case .actionsWithWhen(let name, let actions, let when):
            try RuleCreatorActions.init(name: name, actions: actions, when: when).encode(to: encoder)
        case .mongoDb(let namespace, let rule):
            try RuleCreatorMongoDb.init(namespace: namespace, rule: rule).encode(to: encoder)
        }
    }
}

public struct RuleCreatorActions: Encodable {
    public let name: String
    public let actions: RuleActionsCreator
    public let when: Document

    public init(name: String,
                actions: RuleActionsCreator,
                when: Document = [:]) {
        self.name = name
        self.actions = actions
        self.when = when
    }
}

public class RuleCreatorMongoDb: Encodable {
    let namespace: String
    let rule: Document

    public init(namespace: String, rule: Document) {
        self.namespace = namespace
        self.rule = rule
    }

    public func encode(to encoder: Encoder) throws {
        var creator = rule
        creator["namespace"] = namespace
        try creator.encode(to: encoder)
    }
}

// Allowed actions for an AWS service rule
private struct AWSRuleActions: Encodable {
    let actions: [String]

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for action in actions {
            try container.encode(action)
        }
    }
}

/// Allowed actions for an AWS S3 service rule
private struct AWSS3RuleActions: RuleActions {
    let put, signPolicy: Bool
}

/// Allowed actions for an AWS SES service rule
private struct AWSSESRuleActions: RuleActions {
    let send: Bool
}

/// Allowed actions for an FCM service rule
private struct FCMRuleActions: RuleActions {
    let send: Bool
}

/// Allowed actions for a Twilio service rule
private struct TwilioRuleActions: RuleActions {
    let send: Bool
}

/// Allowed actions for an HTTP service rule
private struct HTTPRuleActions: RuleActions {
    let get, post, put, delete, patch, head: Bool
}

public enum RuleActionsCreator: Encodable {
    /// - parameter get: allow GET method
    /// - parameter post: allow POST method
    /// - parameter put: allow PUT method
    /// - parameter delete: allow DELETE method
    /// - parameter patch: allow PATCH method
    /// - parameter head: allow HEAD method
    case http(get: Bool, post: Bool, put: Bool, delete: Bool, patch: Bool, head: Bool)
    /// - parameter send: allow message sending
    case twilio(send: Bool)
    /// - parameter actions: specify allowed AWS actions
    case aws(actions: [String])
    /// - parameter putObject: allow object putting, signPolicy: allow policy signing
    case awsS3(put: Bool, signPolicy: Bool)
    /// - parameter send: allow message sending
    case awsSes(send: Bool)
    /// - parameter send: allow message sending
    case fcm(send: Bool)

    public func encode(to encoder: Encoder) throws {
        /// encode a rule to its associated wrapper
        switch self {
        case .http(let get, let post, let put, let delete, let patch, let head):
            try HTTPRuleActions.init(get: get,
                                     post: post,
                                     put: put,
                                     delete: delete,
                                     patch: patch,
                                     head: head).encode(to: encoder)
        case .twilio(let send):
            try TwilioRuleActions.init(send: send).encode(to: encoder)
        case .aws(let actions):
            try AWSRuleActions.init(actions: actions).encode(to: encoder)
        case .awsS3(let put, let signPolicy):
            try AWSS3RuleActions.init(put: put, signPolicy: signPolicy).encode(to: encoder)
        case .awsSes(let send):
            try AWSSESRuleActions.init(send: send).encode(to: encoder)
        case .fcm(let send):
            try FCMRuleActions.init(send: send).encode(to: encoder)
        }
    }
}

public struct RuleResponse: Codable {
    init() {
        fatalError("RuleView not implemented")
    }
}
