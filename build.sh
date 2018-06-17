#!/bin/bash

build_variant() (
    local project=$1
    local scheme=$2

    printf '\033[1;35m'
    echo "==================== BUILD SCHEME $scheme ===================="
    printf '\033[0m'

    xcodebuild \
        -project "$(pwd)/$project" \
        -sdk "iphonesimulator" \
        -derivedDataPath "frameworks/data" \
        -scheme $scheme \
        -quiet \
        OTHER_LDFLAGS="-rpath $(pwd)/MobileSDKs/iphoneos/lib" \
        LIBRARY_SEARCH_PATHS="$(pwd)/MobileSDKs/iphoneos/lib" \
        SWIFT_INCLUDE_PATHS="$(pwd)/MobileSDKs/include MobileSDKs/include/libbson-1.0 $(pwd)/MobileSDKs/include/libmongoc-1.0 $(pwd)/MobileSDKs/include/mongo/embedded-v1/" \
        FRAMEWORK_INCLUDE_PATHS="$(pwd)/frameworks" \
        ENABLE_BITCODE=NO \
        IPHONEOS_DEPLOYMENT_TARGET="8.0"

    printf '\033[1;35m'
    echo "==================== BUILD SUCCESSFUL for $scheme ===================="
    printf '\033[0m'
)

# vendor in MongoSwift
# if [ ! -d MongoSwift.framework ]; then
#     echo "vendoring in mongo swift..."
#     curl -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball/v0.0.2 > mongo-swift.tgz
#     mkdir mongo-swift
#     tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1
#     cp -r mongo-swift/ MongoSwift
    
#     rm -rf mongo-swift mongo-swift.tgz
#     cd MongoSwift
#     swift package generate-xcodeproj
#     # xcodebuild \
#     #     -project MongoSwift.xcodeproj \
#     #     -sdk "iphoneos" \
#     #     -arch "arm64" \
#     #     -derivedDataPath data \
#     #     -scheme MongoSwift-Package \
#     #     OTHER_LDFLAGS="-rpath ../MobileSDKs/iphoneos/lib" \
#     #     LIBRARY_SEARCH_PATHS="../MobileSDKs/iphoneos/lib" \
#     #     SWIFT_INCLUDE_PATHS="../MobileSDKs/include ../MobileSDKs/include/libbson-1.0 ../MobileSDKs/include/libmongoc-1.0" \
#     #     ENABLE_BITCODE=NO \
#     #     IPHONEOS_DEPLOYMENT_TARGET="8.0"

#     xcodebuild \
#         -project MongoSwift.xcodeproj \
#         -sdk "iphonesimulator" \
#         -derivedDataPath data \
#         -scheme MongoSwift-Package \
#         OTHER_LDFLAGS="-rpath ../MobileSDKs/iphoneos/lib" \
#         LIBRARY_SEARCH_PATHS="../MobileSDKs/iphoneos/lib" \
#         SWIFT_INCLUDE_PATHS="../MobileSDKs/include ../MobileSDKs/include/libbson-1.0 ../MobileSDKs/include/libmongoc-1.0" \
#         ENABLE_BITCODE=NO \
#         IPHONEOS_DEPLOYMENT_TARGET="8.0"

#     # cp -r data/Build/Products/Debug-iphonesimulator/MongoSwift.framework ../MongoSwift_x86_64.framework
#     cp -r data/Build/Products/Debug-iphonesimulator/MongoSwift.framework ../MongoSwift.framework

#     # cp -r data/Build/Products/Debug-iphoneos/MongoSwift.framework ../MongoSwift_arm64.framework

#     cd ..
#     # mkdir MongoSwift.framework
#     # lipo -create MongoSwift_x86_64.framework/MongoSwift MongoSwift_arm64.framework/MongoSwift -output MongoSwift.framework/MongoSwift
#     # cp -r MongoSwift_x86_64.framework/Headers MongoSwift.framework/
#     # cp -r MongoSwift_x86_64.framework/_CodeSignature MongoSwift.framework/
#     # cp MongoSwift_x86_64.framework/Info.plist MongoSwift.framework/
#     # cp -r MongoSwift_x86_64.framework/Modules MongoSwift.framework/
#     # cp -r MongoSwift_x86_64.framework/Modules/MongoSwift.swiftmodule MongoSwift.framework/Modules/
#     # cp -R MongoSwift_arm64.framework/Modules/MongoSwift.swiftmodule/ MongoSwift.framework/Modules/MongoSwift.swiftmodule/
#     # rm -rf MongoSwift_x86_64.framework/
#     # rm -rf MongoSwift_arm64.framework/
#     # rm -rf MongoSwift/
# fi

# vendor in libmongoc
if [ ! -d libmongoc ]; then
    git submodule init
    git submodule update
fi

# vendor in MongoMobile
if [ ! -d Core/Services/StitchCoreLocalMongoDBService/Sources/MongoMobile ]; then
    echo "vendoring in mongo mobile..."
    curl -L https://api.github.com/repos/mongodb/swift-mongo-mobile/tarball > mongo-mobile.tgz
    mkdir mongo-mobile
    tar -xzf mongo-mobile.tgz -C mongo-mobile --strip-components 1
    cp -r mongo-mobile/Sources/ Core/Services/StitchCoreLocalMongoDBService/Sources/StitchCoreLocalMongoDBService

    rm -rf mongo-mobile mongo-mobile.tgz
fi

if [ ! -d Core/StitchCoreSDK/StitchCoreSDK.xcodeproj ]; then
    make
fi

if [ ! -d frameworks ]; then
    echo "building frameworks"
    mkdir frameworks

    build_variant "Core/StitchCoreSDK/StitchCoreSDK.xcodeproj" "StitchCoreSDK-Package"
    wait;

    build_variant "Core/Services/StitchCoreAWSS3Service/StitchCoreAWSS3Service.xcodeproj" "StitchCoreAWSS3Service-Package"
    build_variant "Core/Services/StitchCoreAWSSESService/StitchCoreAWSSESService.xcodeproj" "StitchCoreAWSSESService-Package"
    build_variant "Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj" "StitchCoreHTTPService-Package"
    build_variant "Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj" "StitchCoreLocalMongoDBService-Package"
    build_variant "Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj" "StitchCoreRemoteMongoDBService-Package"
    build_variant "Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj" "StitchCoreTwilioService-Package"
    build_variant "Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj" "StitchCoreFCMService-Package"

    wait;

    build_variant "iOS/StitchCore/StitchCore.xcodeproj" "StitchCore";
    wait;

    build_variant "iOS/Services/StitchAWSS3Service/StitchAWSS3Service.xcodeproj" "StitchAWSS3Service"
    build_variant "iOS/Services/StitchAWSSESService/StitchAWSSESService.xcodeproj" "StitchAWSSESService"
    build_variant "iOS/Services/StitchHTTPService/StitchHTTPService.xcodeproj" "StitchHTTPService"
    build_variant "iOS/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj" "StitchLocalMongoDBService"
    build_variant "iOS/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj" "StitchRemoteMongoDBService"
    build_variant "iOS/Services/StitchTwilioService/StitchTwilioService.xcodeproj" "StitchTwilioService"
    build_variant "iOS/Services/StitchFCMService/StitchFCMService.xcodeproj" "StitchFCMService"

    wait;
fi

echo "done!";
