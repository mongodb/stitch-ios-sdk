#!/bin/sh

set -e

# Let this be run from any directory
cd "$(dirname "$0")"/..

function usage() {
    echo "Usage: $0 [analytics]"
    exit 1
}

# Enables builds with analytics
if [ "$1" == "analytics" ]; then
    # Use theme with analytics snippets
    THEME="./contrib/docs-theme/fullwidth-analytics"
elif [[ ! -z "$1" ]]; then
    echo "Unrecognized argument: $1"
    usage
else
    # Use default theme
    THEME="fullwidth"
fi

sourcekitten doc --module-name StitchCoreSDK -- -workspace ./Stitch.xcworkspace -scheme StitchCoreSDK > .raw_docs.json

sourcekitten doc --module-name StitchCoreAWSService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreAWSService >> .raw_docs.json
sourcekitten doc --module-name StitchCoreFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreFCMService >> .raw_docs.json
sourcekitten doc --module-name StitchCoreHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreHTTPService >> .raw_docs.json
sourcekitten doc --module-name StitchCoreLocalMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreLocalMongoDBService >> .raw_docs.json
sourcekitten doc --module-name StitchCoreRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreRemoteMongoDBService >> .raw_docs.json
sourcekitten doc --module-name StitchCoreTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreTwilioService >> .raw_docs.json

sourcekitten doc --module-name StitchCore -- -workspace ./Stitch.xcworkspace -scheme StitchCore -sdk iphoneos >> .raw_docs.json

sourcekitten doc --module-name StitchAWSService -- -workspace ./Stitch.xcworkspace -scheme StitchAWSService -sdk iphoneos >> .raw_docs.json
sourcekitten doc --module-name StitchFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchFCMService -sdk iphoneos >> .raw_docs.json
sourcekitten doc --module-name StitchHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchHTTPService -sdk iphoneos >> .raw_docs.json
sourcekitten doc --module-name StitchLocalMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchLocalMongoDBService -sdk iphoneos >> .raw_docs.json
sourcekitten doc --module-name StitchRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchRemoteMongoDBService -sdk iphoneos >> .raw_docs.json
sourcekitten doc --module-name StitchTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchTwilioService -sdk iphoneos >> .raw_docs.json

python DocGen/Scripts/merge_json.py .raw_docs.json .raw_docs_merged.json

jazzy -c --config jazzy.json --theme "$THEME" --sourcekitten-sourcefile .raw_docs_merged.json

rm .raw_docs.json .raw_docs_merged.json
