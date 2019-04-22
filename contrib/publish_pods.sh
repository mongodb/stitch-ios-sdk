#!/bin/sh

set -e

# Let this be run from any directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..


# Verify that we are on the master branch
git status | head -n 1 | grep master || (echo "must be on master branch" && exit 1)

CURRENT_VERSION=`cat StitchSDK.podspec | grep "spec.version" | head -1 | cut -d \" -f2`
git tag CURRENT_VERSION
git push upstream CURRENT_VERSION

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
   echo "Publishing $PODSPEC"
   pod trunk push $PODSPEC --allow-warnings --verbose
done
