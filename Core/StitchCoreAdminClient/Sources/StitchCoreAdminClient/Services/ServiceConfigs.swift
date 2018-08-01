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

private struct HTTPServiceConfig: ServiceConfig { }

/// Configuration for an AWS service
private struct AWSServiceConfig: ServiceConfig {
    /// your access key identifier
    private let accessKeyID: String
    /// your secret access key
    private let secretAccessKey: String
    
    fileprivate init(accessKeyID: String,
                     secretAccessKey: String) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }
    
    internal enum CodingKeys: String, CodingKey {
        case accessKeyID = "accessKeyId", secretAccessKey
    }
}

/// Configuration for an AWS S3 service
private struct AWSS3ServiceConfig: ServiceConfig {
    /// aws region
    private let region: String
    /// your access key identifier
    private let accessKeyID: String
    /// your secret access key
    private let secretAccessKey: String
    
    fileprivate init(region: String,
                     accessKeyID: String,
                     secretAccessKey: String) {
        self.region = region
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }
    
    internal enum CodingKeys: String, CodingKey {
        case region, accessKeyID = "accessKeyId", secretAccessKey
    }
}

/// Configuration for an AWS SES service
private struct AWSSESServiceConfig: ServiceConfig {
    /// aws region
    private let region: String
    /// your access key identifier
    private let accessKeyID: String
    /// your secret access key
    private let secretAccessKey: String

    fileprivate init(region: String,
                     accessKeyID: String,
                     secretAccessKey: String) {
        self.region = region
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }
    
    internal enum CodingKeys: String, CodingKey {
        case region, accessKeyID = "accessKeyId", secretAccessKey
    }
}

/// Configuration for an FCM service
private struct FCMServiceConfig: ServiceConfig {
    /// your sender id
    private let senderID: String
    /// your API key
    private let apiKey: String
    
    fileprivate init(senderID: String,
                     apiKey: String) {
        self.senderID = senderID
        self.apiKey = apiKey
    }
    
    internal enum CodingKeys: String, CodingKey {
        case senderID = "senderId", apiKey
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

/// Configuration for a Twilio service
private struct MongoDbServiceConfig: ServiceConfig {
    private enum CodingKeys: String, CodingKey {
        case uri
    }
    
    /// the URI of the cluster of this service
    private let uri: String
    
    fileprivate init(uri: String) {
        self.uri = uri
    }
}

/// Convenience enum for creating a new service. Given that there
/// are only a finite number of services, this conforms users
/// to only pick one of the available services
public enum ServiceConfigs: Encodable {
    /// configure an http service
    /// - parameter name: name of this service
    case http(name: String)
    
    /// configure an AWS service
    /// - parameter name: name of this service
    /// - parameter accessKeyID: your access key identifier
    /// - parameter secretAccessKey: your secret access key
    case aws(name: String, accessKeyID: String, secretAccessKey: String)
    
    /// configure an AWS S3 service
    /// - parameter name: name of this service
    /// - parameter region: aws region
    /// - parameter accessKeyID: your access key identifier
    /// - parameter secretAccessKey: your secret access key
    case awsS3(name: String, region: String, accessKeyID: String, secretAccessKey: String)

    /// configure an AWS SES service
    /// - parameter name: name of this service
    /// - parameter region: aws region
    /// - parameter accessKeyID: your access key identifier
    /// - parameter secretAccessKey: your secret access key
    case awsSes(name: String, region: String, accessKeyID: String, secretAccessKey: String)
    
    /// configure an FCM service
    /// - parameter name: name of this service
    /// - parameter senderID: your sender ID
    /// - parameter apiKey: your API key
    case fcm(name: String, senderID: String, apiKey: String)

    /// configure a Twilio service
    /// - parameter name: name of this service
    /// - parameter accountSid: your account identifier
    /// - parameter authToken: your authorization token
    case twilio(name: String, accountSid: String, authToken: String)
    
    /// configure a MongoDB service
    /// - parameter uri: The URI to the MongoDB cluster for this service
    case mongodb(name: String, uri: String)

    public func encode(to encoder: Encoder) throws {
        // wrap the config and then
        // encode it to the encoder
        switch self {
        case .http(let name):
            try ServiceConfigWrapper.init(
                name: name,
                type: "http",
                config: HTTPServiceConfig.init()
            ).encode(to: encoder)
        case .aws(let name, let accessKeyID, let secretAccessKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "aws",
                config: AWSServiceConfig.init(accessKeyID: accessKeyID,
                                              secretAccessKey: secretAccessKey)
                ).encode(to: encoder)
        case .awsS3(let name, let region, let accessKeyID, let secretAccessKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "aws-s3",
                config: AWSS3ServiceConfig.init(region: region,
                                                accessKeyID: accessKeyID,
                                                secretAccessKey: secretAccessKey)
                ).encode(to: encoder)
        case .awsSes(let name, let region, let accessKeyID, let secretAccessKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "aws-ses",
                config: AWSSESServiceConfig.init(region: region,
                                                 accessKeyID: accessKeyID,
                                                 secretAccessKey: secretAccessKey)
            ).encode(to: encoder)
        case .fcm(let name, let senderID, let apiKey):
            try ServiceConfigWrapper.init(
                name: name,
                type: "gcm",
                config: FCMServiceConfig.init(senderID: senderID,
                                              apiKey: apiKey)
            ).encode(to: encoder)
        case .twilio(let name, let accountSid, let authToken):
            try ServiceConfigWrapper.init(
                name: name,
                type: "twilio",
                config: TwilioServiceConfig.init(accountSid: accountSid,
                                                 authToken: authToken)
            ).encode(to: encoder)
        case .mongodb(let name, let uri):
            try ServiceConfigWrapper.init(
                name: name,
                type: "mongodb",
                config: MongoDbServiceConfig.init(uri: uri)
            ).encode(to: encoder)
        }
    
    }
}
