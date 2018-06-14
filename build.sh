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

# download module definitions for libmongoc/libbson
[[ -d Sources/libbson ]] || git clone --depth 1 https://github.com/mongodb/swift-bson Sources/libbson
[[ -d Sources/libmongoc ]] || git clone --depth 1 https://github.com/mongodb/swift-mongoc Sources/libmongoc

# download mobile SDKs
mkdir -p MobileSDKs && cd MobileSDKs
download_and_combine "iphone"
download_and_combine "appletv"
cd ..

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
