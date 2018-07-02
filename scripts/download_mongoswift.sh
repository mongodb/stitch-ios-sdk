# download MongoSwift
if [ ! -d MongoSwift ]; then
  curl -# -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball > mongo-swift.tgz
  mkdir mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1

  cp -r mongo-swift/Sources/MongoSwift MongoSwift
  rm -rf mongo-swift mongo-swift.tgz
fi
if [ ! -d CommonCrypto ]; then
  curl -# -L https://api.github.com/repos/kylef-archive/CommonCrypto/tarball > commoncrypto.tgz
  mkdir CommonCrypto
  tar -xzf commoncrypto.tgz -C CommonCrypto --strip-components 1
  rm -rf cryptoswift.tgz
  cp -r CommonCrypto Frameworks/macos
fi
# if [ ! -d Swifter ]; then
#   curl -# -L https://api.github.com/repos/httpswift/swifter/tarball > swifter.tgz
#   mkdir Swifter
#   # extract mongo-swift
#   tar -xzf swifter.tgz -C Swifter --strip-components 1
#   rm -rf swifter.tgz
# fi

# if [ ! -d JSONWebToken ]; then
#   curl -# -L https://api.github.com/repos/kylef/JSONWebToken.swift/tarball > jsonwebtoken.tgz
#   mkdir JSONWebToken

#   tar -xzf jsonwebtoken.tgz -C JSONWebToken --strip-components 1
#   rm -rf jsonwebtoken.tgz
# fi

# if [ ! -d CryptoSwift ]; then
#   curl -# -L https://api.github.com/repos/krzyzanowskim/CryptoSwift/tarball > cryptoswift.tgz
#   mkdir CryptoSwift
#   tar -xzf cryptoswift.tgz -C CryptoSwift --strip-components 1
#   rm -rf cryptoswift.tgz
# fi



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

# if [ ! -d Frameworks/macos/JWA.framework ]; then
#   python scripts/frameworkify \
#     MockUtils/Sources \
#     -sdk macosx \
#     -target 10.10 \
#     -o MockUtils
# fi

# if [ ! -d Frameworks/libbson/libmongoc.framework ]; then
#   python scripts/frameworkify \
#     libmongoc \
#     -sdk=iphonesimulator \
#     -target=10.2 \
#     -F Frameworks/ios \
#     -o libmongoc -v
# fi

# if [ ! -d Frameworks/libmongoc/libmongoc.framework ]; then
#   python scripts/frameworkify \
#     libmongoc \
#     -sdk=iphonesimulator \
#     -target=10.2 \
#     -F Frameworks/ios \
#     -o libmongoc -v
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

# xcrun xctest Frameworks/macos/StitchCoreSDKTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreAWSS3ServiceTests.xctest/ &
# xcrun xctest Frameworks/macos/StitchCoreAWSSESServiceTests.xctest/ &

wait
