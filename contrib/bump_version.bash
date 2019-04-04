#!/bin/sh

set -e

# Let this be run from any directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..

# Determine the bump type from the user input
BUMP_TYPE=$1
if [ "$BUMP_TYPE" != "patch" ] && [ "$BUMP_TYPE" != "minor" ] && [ "$BUMP_TYPE" != "major" ]; then
	echo $"Usage: $0 <patch|minor|major>"
	exit 1
fi

# Get the current package version
LAST_VERSION=`cat StitchSDK.podspec | grep "spec.version" | head -1 | cut -d \" -f2`
LAST_VERSION_MAJOR=$(echo $LAST_VERSION | cut -d. -f1)
LAST_VERSION_MINOR=$(echo $LAST_VERSION | cut -d. -f2)
LAST_VERSION_PATCH=$(echo $LAST_VERSION | cut -d. -f3)

# Construct the new package version
NEW_VERSION_MAJOR=$LAST_VERSION_MAJOR
NEW_VERSION_MINOR=$LAST_VERSION_MINOR
NEW_VERSION_PATCH=$LAST_VERSION_PATCH

if [ "$BUMP_TYPE" == "patch" ]; then
	NEW_VERSION_PATCH=$(($LAST_VERSION_PATCH+1))
elif [ "$BUMP_TYPE" == "minor" ]; then
	NEW_VERSION_MINOR=$(($LAST_VERSION_MINOR+1))
	NEW_VERSION_PATCH=0
else
	NEW_VERSION_MAJOR=$(($LAST_VERSION_MAJOR+1))
	NEW_VERSION_MINOR=0
	NEW_VERSION_PATCH=0
fi

NEW_VERSION=$NEW_VERSION_MAJOR.$NEW_VERSION_MINOR.$NEW_VERSION_PATCH

echo "Bumping $LAST_VERSION to $NEW_VERSION ($BUMP_TYPE)"

# Update all of the podspecs
echo "Updating podspecs"
REGEX_SAFE_LAST_VERSION="$LAST_VERSION_MAJOR\.$LAST_VERSION_MINOR\.$LAST_VERSION_PATCH"
PODSPEC_SED_REGEX="s/$REGEX_SAFE_LAST_VERSION/$NEW_VERSION/g"

# Declare the list of podspecs to be modified
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
   echo "Updating $PODSPEC"
   sed -i "" -E "$PODSPEC_SED_REGEX" $PODSPEC
   git add $PODSPEC
done

echo "Updating README"
sed -i "" -E "$PODSPEC_SED_REGEX" README.md
git add README.md
