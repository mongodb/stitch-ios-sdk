#!/bin/sh

set -e

VERSION=`cat StitchSDK.podspec | grep "spec.version" | head -1 | cut -d \" -f2`
VERSION_MAJOR=$(echo $VERSION | cut -d. -f1)
VERSION_MINOR=$(echo $VERSION | cut -d. -f2)
VERSION_PATCH=$(echo $VERSION | cut -d. -f3 | cut -d- -f1)
VERSION_QUALIFIER=$(echo $VERSION | cut -d- -f2 -s)
VERSION_QUALIFIER_INC=$(echo $VERSION | cut -d- -f3 -s)

contrib/generate_docs.sh

if ! which aws; then
   echo "aws CLI not found. see: https://docs.aws.amazon.com/cli/latest/userguide/installing.html"
   exit 1
fi

if [ -z "$VERSION_QUALIFIER" ]; then
	# Publish to MAJOR, MAJOR.MINOR
	aws s3 cp docs s3://stitch-sdks/stitch-sdks/swift/$VERSION_MAJOR --recursive --acl public-read
	aws s3 cp docs s3://stitch-sdks/stitch-sdks/swift/$VERSION_MAJOR.$VERSION_MINOR --recursive --acl public-read
fi

# Publish to full version
aws s3 cp docs s3://stitch-sdks/stitch-sdks/swift/$VERSION --recursive --acl public-read

BRANCH_NAME=`git branch | grep -e "^*" | cut -d' ' -f 2`
aws s3 cp docs s3://stitch-sdks/stitch-sdks/swift/branch/$BRANCH_NAME --recursive --acl public-read
