#!/bin/sh

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

check_swiftlint() {
	if [[ $(swiftlint) ]]; then
		swiftlint
		echo "treating all linter warnings as errors, exiting lint script"
		return 1
	fi
}

set -e

pushd Core

pushd StitchCoreSDK
echo "currently ignoring linter warnings in StitchCoreSDK until STITCH-2269 is completed"
# TODO: when STITCH-2269 is completed, remove the echo and make this a "check_swiftlint"
swiftlint
popd

pushd StitchCoreTestUtils
check_swiftlint
popd

pushd StitchCoreAdminClient
check_swiftlint
popd

pushd Services

pushd StitchCoreAWSS3Service
check_swiftlint
popd

pushd StitchCoreAWSService
check_swiftlint
popd

pushd StitchCoreAWSSESService
check_swiftlint
popd

pushd StitchCoreFCMService
check_swiftlint
popd

pushd StitchCoreHTTPService
check_swiftlint
popd

pushd StitchCoreLocalMongoDBService
check_swiftlint
popd

pushd StitchCoreRemoteMongoDBService
check_swiftlint
popd

pushd StitchCoreTwilioService
check_swiftlint
popd

popd # Core/Services

popd # Core

pushd Darwin

pushd StitchCore
check_swiftlint
popd

pushd StitchDarwinCoreTestUtils
check_swiftlint
popd

pushd StitchSDK
check_swiftlint
popd

pushd Services

pushd StitchAWSS3Service
check_swiftlint
popd

pushd StitchAWSService
check_swiftlint
popd

pushd StitchAWSSESService
check_swiftlint
popd

pushd StitchFCMService
check_swiftlint
popd

pushd StitchHTTPService
check_swiftlint
popd

pushd StitchLocalMongoDBService
check_swiftlint
popd

pushd StitchRemoteMongoDBService
check_swiftlint
popd

pushd StitchTwilioService
check_swiftlint
popd

popd # Darwin/Services

popd # Darwin
