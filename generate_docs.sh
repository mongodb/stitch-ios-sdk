set -e

sourcekitten doc --module-name StitchCoreSDK -- -workspace ./Stitch.xcworkspace -scheme StitchCoreSDK-Package -xcconfig kitten.xcconfig > sdk_docs_kitten_output.json

sourcekitten doc --module-name StitchCoreAWSSESService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreAWSSESService-Package -xcconfig kitten.coreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchCoreFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreFCMService-Package -xcconfig kitten.coreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchCoreHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreHTTPService-Package -xcconfig kitten.coreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchCoreRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreRemoteMongoDBService-Package -xcconfig kitten.coreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchCoreTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchCoreTwilioService-Package -xcconfig kitten.coreservice.xcconfig >> sdk_docs_kitten_output.json

sourcekitten doc --module-name StitchCore -- -workspace ./Stitch.xcworkspace -scheme StitchCore -arch arm64 -xcconfig kitten.ioscore.xcconfig >> sdk_docs_kitten_output.json

sourcekitten doc --module-name StitchAWSS3Service -- -workspace ./Stitch.xcworkspace -scheme StitchAWSS3Service -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchAWSSESService -- -workspace ./Stitch.xcworkspace -scheme StitchAWSSESService -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchFCMService -- -workspace ./Stitch.xcworkspace -scheme StitchFCMService -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchHTTPService -- -workspace ./Stitch.xcworkspace -scheme StitchHTTPService -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchRemoteMongoDBService -- -workspace ./Stitch.xcworkspace -scheme StitchRemoteMongoDBService -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json
sourcekitten doc --module-name StitchTwilioService -- -workspace ./Stitch.xcworkspace -scheme StitchTwilioService -arch arm64 -xcconfig kitten.ioscoreservice.xcconfig >> sdk_docs_kitten_output.json

python merge_json.py sdk_docs_kitten_output.json raw_docs.json

rm sdk_docs_kitten_output.json
