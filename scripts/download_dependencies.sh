# download MongoSwift
if [ ! -d MongoSwift ]; then
  curl -# -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball > mongo-swift.tgz
  mkdir mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1

  cp -r mongo-swift/Sources/MongoSwift MongoSwift
  rm -rf mongo-swift mongo-swift.tgz
fi

if [ ! -d scripts/pbxproj ]; then
  git clone https://github.com/kronenthaler/mod-pbxproj.git --branch 2.5.1
  mv mod-pbxproj/pbxproj scripts
  rm -rf mod-pbxproj
fi

# if [ ! -d scripts/future ]; then
#   curl -# -L https://files.pythonhosted.org/packages/00/2b/8d082ddfed935f3608cc61140df6dcbf0edea1bc3ab52fb6c29ae3e81e85/future-0.16.0.tar.gz > future.tgz
#   mkdir future
#   tar -xzf future.tgz -C future --strip-components 1
#   cd future
#   export PYTHONPATH=$PYTHONPATH:~/local/lib/python3.6/site-packages/
#   /usr/local/opt/python3/bin/python3 setup.py install --prefix=~/local
# fi

if [ ! -d Swifter ]; then
  curl -# -L https://api.github.com/repos/httpswift/swifter/tarball > swifter.tgz
  mkdir Swifter
  # extract mongo-swift
  tar -xzf swifter.tgz -C Swifter --strip-components 1
  rm -rf swifter.tgz
fi

if [ ! -d JSONWebToken ]; then
  curl -# -L https://api.github.com/repos/kylef/JSONWebToken.swift/tarball > jsonwebtoken.tgz
  mkdir JSONWebToken

  tar -xzf jsonwebtoken.tgz -C JSONWebToken --strip-components 1
  rm -rf jsonwebtoken.tgz
fi

if [ ! -d CryptoSwift ]; then
  curl -# -L https://api.github.com/repos/krzyzanowskim/CryptoSwift/tarball > cryptoswift.tgz
  mkdir CryptoSwift
  tar -xzf cryptoswift.tgz -C CryptoSwift --strip-components 1
  rm -rf cryptoswift.tgz
fi

# if [ ! -d Frameworks/macos/Swifter.framework ]; then
#   python scripts/frameworkify \
#     Swifter/Sources \
#     -sdk=macosx \
#     -target=10.10 \
#     -F Frameworks/macos \
#     -o Swifter -v \
#     -I CommonCrypto
# fi

# if [ ! -d Frameworks/macos/JWA.framework ]; then
#   python scripts/frameworkify \
#     JSONWebToken/Sources/JWA \
#     -sdk=macosx \
#     -target=10.10 \
#     -F Frameworks/macos \
#     -o JWA -v -I CommonCrypto --excludes JSONWebToken/Sources/JWA/HMAC/HMACCryptoSwift.swift
# fi

# if [ ! -d Frameworks/macos/JWT.framework ]; then
#   python scripts/frameworkify \
#     JSONWebToken/Sources/JWT \
#     -sdk=macosx \
#     -target=10.10 \
#     -F Frameworks/macos \
#     -o JWT -v \
#     -I CommonCrypto \
#     --excludes JSONWebToken/Sources/JWA/HMAC/HMACCryptoSwift.swift
# fi

# if [ ! -d Frameworks/macos/MockUtils.framework ]; then
#   python scripts/frameworkify \
#     MockUtils/Sources \
#     -sdk macosx \
#     -target 10.10 \
#     -o MockUtils
# fi

# if [ ! -d Frameworks/ios/MongoSwift.framework ]; then
#   python scripts/frameworkify \
#     MongoSwift \
#     -sdk=iphonesimulator \
#     -target=10.2 \
#     -F Frameworks/ios \
#     -o MongoSwift -v
# fi

# if [ ! -d Frameworks/macos/MockUtils.framework ]; then
#   python scripts/frameworkify \
#     MockUtils/Sources/MockUtils \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos -o MockUtils -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreAdminClient.framework ]; then
#   python scripts/frameworkify \
#     Core/StitchCoreAdminClient/Sources \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreAdminClient -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreSDK.framework ]; then
#   python scripts/frameworkify \
#     Core/StitchCoreSDK/Sources/StitchCoreSDK \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos -o StitchCoreSDK -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreSDKMocks.framework ]; then
#   python scripts/frameworkify \
#     Core/StitchCoreSDK/Sources/StitchCoreSDKMocks \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -I CommonCrypto \
#     -F Frameworks/macos \
#     -o StitchCoreSDKMocks -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreTestUtils.framework ]; then
#   python scripts/frameworkify \
#     Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -I CommonCrypto \
#     -F Frameworks/macos \
#     -o StitchCoreTestUtils -v
#   mv Frameworks/macos/StitchCoreTestUtils.xctest Frameworks/macos/StitchCoreTestUtils.framework
# fi

# if [ ! -d Frameworks/macos/StitchCoreSDKTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/StitchCoreSDK/Tests/StitchCoreSDKTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -I CommonCrypto/ \
#     -o StitchCoreSDKTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreAWSS3Service.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreAWSS3Service -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreAWSS3ServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreAWSS3Service/Tests/StitchCoreAWSS3ServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreAWSS3ServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreAWSSESService.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreAWSSESService -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreAWSSESServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreAWSSESService/Tests/StitchCoreAWSSESServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreAWSSESServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreFCMService.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreFCMService/Sources/StitchCoreFCMService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreFCMService -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreFCMServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreFCMService/Tests/StitchCoreFCMServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreFCMServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreHTTPService.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreHTTPService -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreHTTPServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreHTTPService/Tests/StitchCoreHTTPServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreHTTPServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreRemoteMongoDBService.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreRemoteMongoDBService -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreRemoteMongoDBServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreRemoteMongoDBService/Tests/StitchCoreRemoteMongoDBServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreRemoteMongoDBServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreTwilioService.framework ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreTwilioService -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreTwilioServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Core/Services/StitchCoreTwilioService/Tests/StitchCoreTwilioServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCoreTwilioServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchDarwinCoreTestUtils.framework ]; then
#   python scripts/frameworkify \
#     Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchDarwinCoreTestUtils -v
#     mv Frameworks/macos/StitchDarwinCoreTestUtils.xctest Frameworks/macos/StitchDarwinCoreTestUtils.framework
# fi

# if [ ! -d Frameworks/macos/StitchCore.framework ]; then
#   python scripts/frameworkify \
#     Darwin/StitchCore/StitchCore \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCore -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/StitchCore/StitchCoreTests Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils  Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -I CommonCrypto \
#     -o StitchCoreTests -v
# fi

# if [ ! -d Frameworks/macos/StitchCore.framework ]; then
#   python scripts/frameworkify \
#     Darwin/StitchCore/StitchCore \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchCore -v
# fi

# if [ ! -d Frameworks/macos/StitchCoreTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/StitchCore/StitchCoreTests Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils  Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -I CommonCrypto \
#     -o StitchCoreTests -v
# fi


# if [ ! -d Frameworks/macos/StitchAWSS3Service.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchAWSS3Service/StitchAWSS3Service \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchAWSS3Service -v
# fi

# if [ ! -d Frameworks/macos/StitchAWSS3ServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchAWSS3Service/StitchAWSS3ServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchAWSS3ServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchAWSSESService.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchAWSSESService/StitchAWSSESService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchAWSSESService -v
# fi

# if [ ! -d Frameworks/macos/StitchAWSSESServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchAWSSESService/StitchAWSSESServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchAWSSESServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchFCMService.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchFCMService/StitchFCMService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchFCMService -v
# fi

# if [ ! -d Frameworks/macos/StitchFCMServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchFCMService/StitchFCMServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchFCMServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchHTTPService.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchHTTPService/StitchHTTPService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchHTTPService -v
# fi

# if [ ! -d Frameworks/macos/StitchHTTPServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchHTTPService/StitchHTTPServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchHTTPServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchRemoteMongoDBService.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchRemoteMongoDBService -v
# fi

# if [ ! -d Frameworks/macos/StitchRemoteMongoDBServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchRemoteMongoDBServiceTests -v
# fi

# if [ ! -d Frameworks/macos/StitchTwilioService.framework ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchTwilioService/StitchTwilioService \
#     -enable-testing \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchTwilioService -v
# fi

# if [ ! -d Frameworks/macos/StitchTwilioServiceTests.xctest ]; then
#   python scripts/frameworkify \
#     Darwin/Services/StitchTwilioService/StitchTwilioServiceTests \
#     -xct \
#     -sdk macosx \
#     -target 10.10 \
#     -F Frameworks/macos \
#     -o StitchTwilioServiceTests -v
# fi

# xcrun xctest Frameworks/macos/StitchCoreSDKTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreAWSS3ServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreAWSSESServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreFCMServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreHTTPServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreRemoteMongoDBServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreTwilioServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreTests.xctest/ &

wait
