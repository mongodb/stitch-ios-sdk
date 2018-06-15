// Re-exported classes, structs, protocols, and enums from StitchCoreSDK and the iOS-specific service modules

////////////////
// StitchCore //
////////////////

// from core:

// StitchCoreSDK/
@_exported import class StitchCore.StitchAppClientConfiguration
@_exported import class StitchCore.StitchAppClientConfigurationBuilder
@_exported import enum StitchCore.StitchAppClientConfigurationError
@_exported import struct StitchCore.StitchAppClientInfo
@_exported import class StitchCore.StitchClientConfiguration
@_exported import enum StitchCore.StitchClientConfigurationError
@_exported import enum StitchCore.StitchError
@_exported import enum StitchCore.StitchServiceErrorCode
@_exported import enum StitchCore.StitchRequestErrorCode
@_exported import enum StitchCore.StitchClientErrorCode

// StitchCoreSDK/Auth/
@_exported import protocol StitchCore.StitchCredential
@_exported import enum StitchCore.StitchProviderType
@_exported import protocol StitchCore.StitchUserIdentity
@_exported import protocol StitchCore.StitchUserProfile
@_exported import protocol StitchCore.ExtendedStitchUserProfile

// StitchCoreSDK/Auth/Providers/
@_exported import struct StitchCore.AnonymousCredential
@_exported import struct StitchCore.CustomCredential
@_exported import struct StitchCore.FacebookCredential
@_exported import struct StitchCore.GoogleCredential
@_exported import struct StitchCore.ServerAPIKeyCredential
@_exported import struct StitchCore.UserAPIKey
@_exported import struct StitchCore.UserAPIKeyCredential
@_exported import struct StitchCore.UserPasswordCredential

// from iOS-specific module:

// StitchCore/Core
@_exported import class StitchCore.Stitch
@_exported import protocol StitchCore.StitchAppClient
@_exported import enum StitchCore.StitchResult

// StitchCore/Core/Auth
@_exported import protocol StitchCore.StitchAuth
@_exported import protocol StitchCore.StitchAuthDelegate
@_exported import protocol StitchCore.StitchUser

// StitchCore/Core/Auth/Providers
@_exported import class StitchCore.UserAPIKeyAuthProvider
@_exported import protocol StitchCore.UserAPIKeyAuthProviderClient
@_exported import class StitchCore.UserPasswordAuthProvider
@_exported import protocol StitchCore.UserPasswordAuthProviderClient
@_exported import protocol StitchCore.AuthProviderClientFactory
@_exported import protocol StitchCore.NamedAuthProviderClientFactory

// StitchCore/Core/Push
@_exported import protocol StitchCore.StitchPush

////////////////////////
// StitchAWSS3Service //
////////////////////////

// from core
@_exported import struct StitchAWSS3Service.AWSS3PutObjectResult
@_exported import struct StitchAWSS3Service.AWSS3SignPolicyResult

// from iOS-specific module
@_exported import protocol StitchAWSS3Service.AWSS3ServiceClient
@_exported import class StitchAWSS3Service.AWSS3Service

/////////////////////////
// StitchAWSSESService //
/////////////////////////

// from core
@_exported import struct StitchAWSSESService.AWSSESSendResult

// from iOS-specific module
@_exported import protocol StitchAWSSESService.AWSSESServiceClient
@_exported import class StitchAWSSESService.AWSSESService

//////////////////////
// StitchFCMService //
//////////////////////

// from core
@_exported import struct StitchCoreFCMService.FCMSendMessageNotification
@_exported import class StitchCoreFCMService.FCMSendMessageNotificationBuilder
@_exported import enum StitchCoreFCMService.FCMSendMessagePriority
@_exported import struct StitchCoreFCMService.FCMSendMessageRequest
@_exported import class StitchCoreFCMService.FCMSendMessageRequestBuilder
@_exported import struct StitchCoreFCMService.FCMSendMessageResult
@_exported import struct StitchCoreFCMService.FCMSendMessageResultFailureDetail

// from iOS-specific module
@_exported import protocol StitchFCMService.FCMServicePushClient
@_exported import let StitchFCMService.fcmServicePushClientFactory
@_exported import protocol StitchFCMService.FCMServiceClient
@_exported import let StitchFCMService.fcmServiceClientFactory


///////////////////////
// StitchHTTPService //
///////////////////////

// from core
@_exported import struct StitchHTTPService.HTTPCookie
@_exported import enum StitchHTTPService.HTTPMethod
@_exported import struct StitchHTTPService.HTTPRequest
@_exported import class StitchHTTPService.HTTPRequestBuilder
@_exported import enum StitchHTTPService.HTTPRequestBuilderError
@_exported import struct StitchHTTPService.HTTPResponse

// from iOS-specific module
@_exported import protocol StitchHTTPService.HTTPServiceClient
@_exported import class StitchHTTPService.HTTPService

////////////////////////////////
// StitchRemoteMongoDBService //
////////////////////////////////

// from core
@_exported import struct StitchRemoteMongoDBService.RemoteCountOptions
@_exported import struct StitchRemoteMongoDBService.RemoteDeleteResult
@_exported import struct StitchRemoteMongoDBService.RemoteFindOptions
@_exported import struct StitchRemoteMongoDBService.RemoteInsertManyResult
@_exported import struct StitchRemoteMongoDBService.RemoteInsertOneResult
@_exported import struct StitchRemoteMongoDBService.RemoteUpdateOptions
@_exported import struct StitchRemoteMongoDBService.RemoteUpdateResult

// from iOS-specific module
@_exported import class StitchRemoteMongoDBService.RemoteMongoDBService
@_exported import class StitchRemoteMongoDBService.RemoteMongoClient
@_exported import class StitchRemoteMongoDBService.RemoteMongoCollection
@_exported import class StitchRemoteMongoDBService.RemoteMongoCursor
@_exported import class StitchRemoteMongoDBService.RemoteMongoDatabase
@_exported import class StitchRemoteMongoDBService.RemoteMongoReadOperation

/////////////////////////
// StitchTwilioService //
/////////////////////////

// from iOS-specific module
@_exported import class StitchTwilioService.TwilioService
@_exported import protocol StitchTwilioService.TwilioServiceClient
