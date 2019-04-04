#!/bin/sh

set -e

# Let this be run from any directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..

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

pushd Core

pushd StitchCoreSDK
check_swiftlint
popd

pushd StitchCoreTestUtils
check_swiftlint
popd

pushd StitchCoreAdminClient
check_swiftlint
popd

pushd Services

pushd StitchCoreAWSService
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

pushd StitchAWSService
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
