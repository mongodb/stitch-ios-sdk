#!/bin/sh

set -e

pod lib lint Core/StitchCoreSDK/StitchCoreSDK.podspec --allow-warnings --verbose

pod lib lint Core/Services/StitchCoreAWSService/StitchCoreAWSService.podspec --allow-warnings --verbose
pod lib lint Core/Services/StitchCoreFCMService/StitchCoreFCMService.podspec --allow-warnings --verbose
pod lib lint Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.podspec --allow-warnings --verbose
pod lib lint Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.podspec --allow-warnings --verbose
pod lib lint Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.podspec --allow-warnings --verbose
pod lib lint Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.podspec --allow-warnings --verbose

pod lib lint Darwin/StitchCore/StitchCore.podspec --allow-warnings --verbose

pod lib lint Darwin/Services/StitchAWSService/StitchAWSService.podspec --allow-warnings --verbose
pod lib lint Darwin/Services/StitchFCMService/StitchFCMService.podspec --allow-warnings --verbose
pod lib lint Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.podspec --allow-warnings --verbose
pod lib lint Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.podspec --allow-warnings --verbose
pod lib lint Darwin/Services/StitchTwilioService/StitchTwilioService.podspec --allow-warnings --verbose
pod lib lint Darwin/Services/StitchHTTPService/StitchHTTPService.podspec --allow-warnings --verbose

pod lib lint StitchSDK.podspec --allow-warnings --verbose