#!/bin/sh

set -e

# Let this be run from any directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..

# Ensure that 'hub' is installed
which hub || (echo "hub is not installed. Please see contrib/README.md for more info" && exit 1)

# Ensure that there are no working changes that will accidentally get committed.
STATUS="$(git status -s)"
if [ -n "$STATUS" ]; then
  echo "Git status is not clean. Refusing to commit."
  echo "Finish your work, then run $0"
  exit 1
fi

# Determine the bump type from the user input
BUMP_TYPE=$1
if [ "$BUMP_TYPE" != "patch" ] && [ "$BUMP_TYPE" != "minor" ] && [ "$BUMP_TYPE" != "major" ]; then
	echo $"Usage: $0 <patch|minor|major> <jira_ticket>"
	exit 1
fi

# Determine the JIRA ticket to include in the commit message for the pull request
JIRA_TICKET=$2
if [ -z "$JIRA_TICKET" ]
    then
        echo $"Usage: must provide Jira ticket number (Ex: STITCH-1234, or 1234)"
        exit 1
fi

 if [[ $JIRA_TICKET != *"-"* ]] ; then
    JIRA_TICKET="STITCH-$JIRA_TICKET"
fi
echo "Jira Ticket: $JIRA_TICKET"
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

# Create the branch for the release PR
RELEASE_BRANCH="Release-$JIRA_TICKET"
git checkout -b $RELEASE_BRANCH
git push -u upstream $RELEASE_BRANCH

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

git commit -m "$JIRA_TICKET Release $NEW_VERSION"
git push -u upstream $RELEASE_BRANCH

echo "creating pull request in github..."
hub pull-request -m "$JIRA_TICKET: Release $NEW_VERSION" --base mongodb:master --head mongodb:$RELEASE_BRANCH
