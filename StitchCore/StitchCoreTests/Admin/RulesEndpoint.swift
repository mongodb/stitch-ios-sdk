import Foundation
import ExtendedJson
@testable import StitchCore

internal protocol RuleActions: Encodable {}
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

internal struct Rule: Encodable {
    let name: String
    let actions: RuleActionsCreator
    let when: Document = [:]
}

private struct AwsSesRuleActions: RuleActions {
    let send: Bool
}
private struct TwilioRuleActions: RuleActions {
    let send: Bool
}
private struct HttpRuleActions: RuleActions {
    let get, post, put, delete, patch, head: Bool
}

internal enum RuleActionsCreator: Encodable {
    case http(get: Bool, post: Bool, put: Bool, delete: Bool, patch: Bool, head: Bool)
    case twilio(send: Bool)
    case awsSes(send: Bool)

    func encode(to encoder: Encoder) throws {
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

internal struct RuleView: Codable {
}

public final class RuleEndpoint: Endpoint, Get, Remove {
    var url: String
    var httpClient: StitchHTTPClient
    typealias Model = RuleView

    init(httpClient: StitchHTTPClient, ruleUrl: String) {
        self.url = ruleUrl
        self.httpClient = httpClient
    }
}

public final class RulesEndpoint: Endpoint, List, Create {
    var url: String
    var httpClient: StitchHTTPClient

    typealias Model = RuleView
    typealias CreatorModel = Rule

    init(httpClient: StitchHTTPClient, rulesUrl: String) {
        self.url = rulesUrl
        self.httpClient = httpClient
    }
}
