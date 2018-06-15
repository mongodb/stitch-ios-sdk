#!/bin/bash

# helper functions
mobile_sdk_url() {
    local variant=$1

    case "$variant" in
    iphoneos)
    echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphoneos-10.2/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d/mongodb_mongo_master_embedded_sdk_iphoneos_10.2_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz"
    ;;

    iphonesimulator)
    echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphonesimulator-10.2/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d/mongodb_mongo_master_embedded_sdk_iphonesimulator_10.2_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz"
    ;;

    appletvos)
    echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-appletvos-10.2/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d/mongodb_mongo_master_embedded_sdk_appletvos_10.2_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz"
    ;;

    appletvsimulator)
    echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-appletvsimulator-10.2/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d/mongodb_mongo_master_embedded_sdk_appletvsimulator_10.2_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz"
    ;;

    macosx)
    echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-macosx-10.10/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d/mongodb_mongo_master_embedded_sdk_macosx_10.10_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz"
    ;;
    esac
}

download_mobile_sdk() {
    local target=$1 url=$2

    echo $url
    curl $url > mobile-sdks.tgz
    mkdir $target
    tar -xzf mobile-sdks.tgz -C $target --strip-components 2
    rm mobile-sdks.tgz
    }

    fix_mongoc_symlinks() {
    local prefix=$1

    rm $prefix/lib/libbson-1.0.dylib
    cp $prefix/lib/libbson-1.0.0.dylib $prefix/lib/libbson-1.0.dylib
    rm $prefix/lib/libmongoc-1.0.dylib
    cp $prefix/lib/libmongoc-1.0.0.dylib $prefix/lib/libmongoc-1.0.dylib
}

download_and_combine() {
    local variant=$1
    local variant_os=${variant}os
    local variant_os_tmp=${variant_os}-tmp
    local variant_simulator=${variant}simulator
    local variant_simulator_tmp=${variant_simulator}-tmp

    if [ ! -d $variant_os ]; then
        download_mobile_sdk $variant_os_tmp $(mobile_sdk_url ${variant_os})
        fix_mongoc_symlinks $variant_os_tmp

        download_mobile_sdk $variant_simulator_tmp $(mobile_sdk_url ${variant_simulator})
        fix_mongoc_symlinks $variant_simulator_tmp

        # create shared include path
        cp -r $variant_os_tmp/include .

        # create combined SDK library paths
        mkdir -p ${variant_os}/lib

        echo "merging architectures into universal dylibs..."
        for lib in $variant_os_tmp/lib/*.dylib; do
            base_lib=$(basename "$lib")
            lipo $variant_os_tmp/lib/${base_lib} $variant_simulator_tmp/lib/${base_lib} -output ${variant_os}/lib/${base_lib} -create
        done

        # cleanup
        rm -rf $variant_os_tmp
        rm -rf $variant_simulator_tmp
    fi
}

build_variant() {
    local project=$1
    local scheme=$2

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
}

# download module definitions for libmongoc/libbson
[[ -d Sources/libbson ]] || git clone --depth 1 https://github.com/mongodb/swift-bson Sources/libbson
[[ -d Sources/libmongoc ]] || git clone --depth 1 https://github.com/mongodb/swift-mongoc Sources/libmongoc

# download mobile SDKs
if [ ! -d MobileSDKs ]; then
    mkdir -p MobileSDKs && cd MobileSDKs
    download_and_combine "iphone"
    download_and_combine "appletv"
    cd ..
fi

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

# vendor in MongoMobile
if [ ! -d MobileSDKs/include/mongo/embedded-v1/mongo_embedded ]; then
    echo "vendoring in mongo mobile..."
    curl -L https://api.github.com/repos/mongodb/swift-mongo-mobile/tarball > mongo-mobile.tgz
    mkdir mongo-mobile
    tar -xzf mongo-mobile.tgz -C mongo-mobile --strip-components 1
    cp -r mongo-mobile/Sources/MongoMobile Core/Services/StitchCoreLocalMongoDBService/Sources/StitchCoreLocalMongoDBService
    cp -r mongo-mobile/Sources/mongo_embedded MobileSDKs/include/mongo/embedded-v1

    rm -rf mongo-mobile mongo-mobile.tgz
fi

if [ ! -d frameworks ]; then
    echo "building frameworks"
    mkdir frameworks

    build_variant "Core/StitchCoreSDK/StitchCoreSDK.xcodeproj" "StitchCoreSDK-Package";
    build_variant "Core/Services/StitchCoreAWSS3Service/StitchCoreAWSS3Service.xcodeproj" "StitchCoreAWSS3Service-Package";
    build_variant "Core/Services/StitchCoreAWSSESService/StitchCoreAWSSESService.xcodeproj" "StitchCoreAWSSESService-Package";
    build_variant "Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj" "StitchCoreHTTPService-Package";
    build_variant "Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj" "StitchCoreLocalMongoDBService-Package";
    build_variant "Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj" "StitchCoreRemoteMongoDBService-Package";
    build_variant "Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj" "StitchCoreTwilioService-Package";
    build_variant "Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj" "StitchCoreFCMService-Package";

    build_variant "iOS/StitchCore/StitchCore.xcodeproj" "StitchCore";
    build_variant "iOS/Services/StitchAWSS3Service/StitchAWSS3Service.xcodeproj" "StitchAWSS3Service";
    build_variant "iOS/Services/StitchAWSSESService/StitchAWSSESService.xcodeproj" "StitchAWSSESService";
    build_variant "iOS/Services/StitchHTTPService/StitchHTTPService.xcodeproj" "StitchHTTPService";
    build_variant "iOS/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj" "StitchLocalMongoDBService";
    build_variant "iOS/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj" "StitchRemoteMongoDBService";
    build_variant "iOS/Services/StitchTwilioService/StitchTwilioService.xcodeproj" "StitchTwilioService";
    build_variant "iOS/Services/StitchFCMService/StitchFCMService.xcodeproj" "StitchFCMService";
fi