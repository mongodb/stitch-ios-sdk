#!/bin/sh

set -ex

pushd "$(dirname "$0")"

USER=`whoami`

./generate_docs.sh analytics

if ! which aws; then
    echo "aws CLI not found. see: https://docs.aws.amazon.com/cli/latest/userguide/installing.html"
    popd > /dev/null
    exit 1
fi

BRANCH_NAME=`git branch | grep -e "^*" | cut -d' ' -f 2`

USER_BRANCH="${USER}/${BRANCH_NAME}"

aws s3 --profile 10gen-noc cp ../docs s3://docs-mongodb-org-staging/stitch/"$USER_BRANCH"/sdk/swift/ --recursive --acl public-read

echo
echo "Staged URL:"
echo "  https://docs-mongodbcom-staging.corp.mongodb.com/stitch/"$USER_BRANCH"/sdk/swift/index.html"

popd > /dev/null
