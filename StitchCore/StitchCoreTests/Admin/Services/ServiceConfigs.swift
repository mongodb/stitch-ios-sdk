import Foundation

private protocol ServiceConfig: Encodable {}
private struct ServiceConfigWrapper<SC: ServiceConfig>: Encodable {
    private let name: String
    private let type: String
    private let config: SC

    fileprivate init(name: String, type: String, config: SC) {
        self.name = name
        self.type = type
        self.config = config
    }
}
private struct HttpServiceConfig: ServiceConfig {}
private struct AwsSesServiceConfig: ServiceConfig {
    private let region: String
    private let accessKeyId: String
    private let secretAccessKey: String

    fileprivate init(region: String,
                     accessKeyId: String,
                     secretAccessKey: String) {
        self.region = region
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}
private struct TwilioServiceConfig: ServiceConfig {
    private enum CodingKeys: String, CodingKey {
        case accountSid = "sid", authToken = "auth_token"
    }

    private let accountSid: String
    private let authToken: String

    fileprivate init(accountSid: String, authToken: String) {
        self.accountSid = accountSid
        self.authToken = authToken
    }
}

internal enum ServiceConfigs: Encodable {
    case http(name: String)
    case awsSes(name: String, region: String, accessKeyId: String, secretAccessKey: String)
    case twilio(name: String, accountSid: String, authToken: String)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .http(let name):
            try ServiceConfigWrapper.init(
                name: name,
                type: "http",
                config: HttpServiceConfig.init()
            ).encode(to: encoder)
        case .awsSes(let name, let region, let accessKeyId, let secretAccessKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "aws-ses",
                config: AwsSesServiceConfig.init(region: region,
                                                 accessKeyId: accessKeyId,
                                                 secretAccessKey: secretAccessKey)
            ).encode(to: encoder)
        case .twilio(let name, let accountSid, let authToken):
            try ServiceConfigWrapper.init(
                name: name,
                type: "twilio",
                config: TwilioServiceConfig.init(accountSid: accountSid,
                                                 authToken: authToken)
            ).encode(to: encoder)
        }
    }
}

