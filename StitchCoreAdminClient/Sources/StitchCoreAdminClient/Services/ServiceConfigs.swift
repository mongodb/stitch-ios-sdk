import Foundation

/// Open protocol for Service configuration conformance
private protocol ServiceConfig: Encodable {}

/// Wrapper for a service config request. A config
/// request requires a `name` and `type` to be included
/// at the top level alongside a `config` object.
/// This wrapper provides that.
private struct ServiceConfigWrapper<SC: ServiceConfig>: Encodable {
    /// name of this service
    private let name: String
    /// the type of service
    private let type: String
    /// the configuration for this service
    private let config: SC

    /// - parameter name: name of this service
    /// - parameter type: the type of service
    /// - parameter config: the configuration for this service
    fileprivate init(name: String, type: String, config: SC) {
        self.name = name
        self.type = type
        self.config = config
    }
}

private struct HttpServiceConfig: ServiceConfig {
    init() {
        fatalError("HttpServiceConfig not implemented")
    }
}

/// Configuration for an AWS S3 service
private struct AwsS3ServiceConfig: ServiceConfig {
    /// aws region
    private let region: String
    /// your access key identifier
    private let accessKeyId: String
    /// your secret access key
    private let secretAccessKey: String
    
    fileprivate init(region: String,
                     accessKeyId: String,
                     secretAccessKey: String) {
        self.region = region
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}

/// Configuration for an AWS SES service
private struct AwsSesServiceConfig: ServiceConfig {
    /// aws region
    private let region: String
    /// your access key identifier
    private let accessKeyId: String
    /// your secret access key
    private let secretAccessKey: String

    fileprivate init(region: String,
                     accessKeyId: String,
                     secretAccessKey: String) {
        self.region = region
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}

/// Configuration for a Twilio service
private struct TwilioServiceConfig: ServiceConfig {
    private enum CodingKeys: String, CodingKey {
        case accountSid = "sid", authToken = "auth_token"
    }

    /// your account identifier
    private let accountSid: String
    /// your authorization token
    private let authToken: String

    fileprivate init(accountSid: String, authToken: String) {
        self.accountSid = accountSid
        self.authToken = authToken
    }
}

/// Convenience enum for creating a new service. Given that there
/// are only a finite number of services, this conforms users
/// to only pick one of the available services
public enum ServiceConfigs: Encodable {
    /// configure an http service
    /// - parameter name: name of this service
    case http(name: String)
    
    /// configure an AWS S3 service
    /// - parameter name: name of this service
    /// - parameter region: aws region
    /// - parameter accessKeyId: your access key identifier
    /// - parameter secretAccessKey: your secret access key
    case awsS3(name: String, region: String, accessKeyId: String, secretAccessKey: String)

    /// configure an AWS SES service
    /// - parameter name: name of this service
    /// - parameter region: aws region
    /// - parameter accessKeyId: your access key identifier
    /// - parameter secretAccessKey: your secret access key
    case awsSes(name: String, region: String, accessKeyId: String, secretAccessKey: String)

    /// configure a Twilio service
    /// - parameter name: name of this service
    /// - parameter accountSid: your account identifier
    /// - parameter authToken: your authorization token
    case twilio(name: String, accountSid: String, authToken: String)

    public func encode(to encoder: Encoder) throws {
        // wrap the config and then
        // encode it to the encoder
        switch self {
        case .http(let name):
            try ServiceConfigWrapper.init(
                name: name,
                type: "http",
                config: HttpServiceConfig.init()
            ).encode(to: encoder)
        case .awsS3(let name, let region, let accessKeyId, let secretAccessKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "aws-s3",
                config: AwsSesServiceConfig.init(region: region,
                                                 accessKeyId: accessKeyId,
                                                 secretAccessKey: secretAccessKey)
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
