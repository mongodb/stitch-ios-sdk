#!/bin/sh

set -e

# Let this be run from any directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..

# Declare the list of pods to be linted
declare -a PODSPECS=(
	"Core/StitchCoreSDK/StitchCoreSDK.podspec"
	"Core/Services/StitchCoreAWSService/StitchCoreAWSService.podspec"
	"Core/Services/StitchCoreFCMService/StitchCoreFCMService.podspec"
	"Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.podspec"
	"Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.podspec"
	"Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.podspec"
	"Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.podspec"

	"Darwin/StitchCore/StitchCore.podspec"

	"Darwin/Services/StitchAWSService/StitchAWSService.podspec"
	"Darwin/Services/StitchFCMService/StitchFCMService.podspec"
	"Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.podspec"
	"Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.podspec"
	"Darwin/Services/StitchTwilioService/StitchTwilioService.podspec"
	"Darwin/Services/StitchHTTPService/StitchHTTPService.podspec"

	"StitchSDK.podspec"
)

for PODSPEC in "${PODSPECS[@]}"
do
   echo "Linting $PODSPEC"
   pod lib lint $PODSPEC --allow-warnings --verboze
done
