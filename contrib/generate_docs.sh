#!/bin/sh

set -e

python scripts/run_xctests.py --test=False

sourcekitten doc --module-name StitchCoreSDK -- -workspace ./Stitch.xcworkspace -scheme StitchCoreSDK-Package -xcconfig DocGen/Configs/kitten.xcconfig > .raw_docs.json

sourcekitten doc --module-name StitchCoreAWSService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreAWSService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreAWSS3Service -- -workspace ./Stitch.xcworkspace -scheme StitchCoreAWSS3Service-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreAWSSESService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreAWSSESService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreFCMService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreHTTPService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreRemoteMongoDBService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchCoreTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreTwilioService-Package -xcconfig DocGen/Configs/kitten.coreservice.xcconfig >> .raw_docs.json

sourcekitten doc --module-name StitchCore -- -workspace ./Stitch.xcworkspace -scheme StitchCore -sdk macosx -xcconfig DocGen/Configs/kitten.ioscore.xcconfig >> .raw_docs.json

sourcekitten doc --module-name StitchAWSService -- -workspace ./Stitch.xcworkspace -scheme StitchAWSService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchAWSS3Service -- -workspace ./Stitch.xcworkspace -scheme StitchAWSS3Service -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchAWSSESService -- -workspace ./Stitch.xcworkspace -scheme StitchAWSSESService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchFCMService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchHTTPService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchRemoteMongoDBService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json
sourcekitten doc --module-name StitchTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchTwilioService -sdk macosx -xcconfig DocGen/Configs/kitten.ioscoreservice.xcconfig >> .raw_docs.json

python DocGen/Scripts/merge_json.py .raw_docs.json .raw_docs_merged.json
jazzy -c --config jazzy.json --sourcekitten-sourcefile .raw_docs_merged.json

rm .raw_docs.json .raw_docs_merged.json
