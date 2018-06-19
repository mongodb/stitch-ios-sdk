# Note on Modules

When you install the MongoDB Stitch iOS SDK via CocoaPods, several importable modules will be available in your project. Some of these modules are meant to be imported, while others are internal dependencies which should not be used as the classes and protocols within them may change at any tiem and result in undefined behavior for your application. This page will list the imports that should and should not be made for each Pod.

## StitchSDK

```swift
// OKAY 
import StitchCore // basic Stitch features
import StitchRemoteMongoDBService // MongoDB Atlas service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreSDK
import StitchCoreRemoteMongoDBService
```

## StitchSDK/StitchAWSS3Service

```swift
// OKAY 
import StitchAWSS3Service // AWS S3 service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreAWSS3Service
```

## StitchSDK/StitchAWSSESService

```swift
// OKAY 
import StitchAWSSESService // AWS SES service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreAWSSESService
```

## StitchSDK/StitchFCMService

```swift
// OKAY 
import StitchFCMService // FCM service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreFCMService
```

## StitchSDK/StitchHTTPService

```swift
// OKAY 
import StitchHTTPService // HTTP service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreHTTPService
```

## StitchSDK/StitchTwilioService

```swift
// OKAY 
import StitchTwilioService // Twilio service features

// DO NOT IMPORT - INTERNAL AND UNSTABLE
import StitchCoreTwilioService
```
