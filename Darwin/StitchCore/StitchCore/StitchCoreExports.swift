// Re-exported classes, structs, protocols, and enums from StitchCoreSDK

// StitchCoreSDK/
@_exported import class StitchCoreSDK.StitchAppClientConfiguration
@_exported import class StitchCoreSDK.StitchAppClientConfigurationBuilder
@_exported import class StitchCoreSDK.StitchClientConfiguration
@_exported import enum StitchCoreSDK.StitchClientConfigurationError
@_exported import enum StitchCoreSDK.StitchError
@_exported import enum StitchCoreSDK.StitchServiceErrorCode
@_exported import enum StitchCoreSDK.StitchRequestErrorCode
@_exported import enum StitchCoreSDK.StitchClientErrorCode

// StitchCoreSDK/Auth/
@_exported import protocol StitchCoreSDK.StitchCredential
@_exported import enum StitchCoreSDK.StitchProviderType
@_exported import protocol StitchCoreSDK.StitchUserIdentity
@_exported import protocol StitchCoreSDK.StitchUserProfile
@_exported import protocol StitchCoreSDK.ExtendedStitchUserProfile

// StitchCoreSDK/Auth/Providers/
@_exported import struct StitchCoreSDK.AnonymousCredential
@_exported import struct StitchCoreSDK.CustomCredential
@_exported import struct StitchCoreSDK.FacebookCredential
@_exported import struct StitchCoreSDK.GoogleCredential
@_exported import struct StitchCoreSDK.ServerAPIKeyCredential
@_exported import struct StitchCoreSDK.UserAPIKey
@_exported import struct StitchCoreSDK.UserAPIKeyCredential
@_exported import struct StitchCoreSDK.UserPasswordCredential

@_exported import struct MongoSwift.Document
@_exported import struct MongoSwift.ObjectId
@_exported import struct MongoSwift.Binary
@_exported import struct MongoSwift.Timestamp
@_exported import struct MongoSwift.CodeWithScope
@_exported import struct MongoSwift.Decimal128
@_exported import struct MongoSwift.MinKey
@_exported import struct MongoSwift.MaxKey
@_exported import class MongoSwift.BsonDecoder
@_exported import class MongoSwift.BsonEncoder
@_exported import enum MongoSwift.BsonSubtype
@_exported import enum MongoSwift.BsonType
