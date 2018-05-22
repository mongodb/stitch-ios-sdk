#!/bin/bash

# MobileSDK links
MOBILE_SDK_IPHONEOS="https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphoneos-10.2/9dbed1bc8108798bebc8ae7a0b56fa4858335146/mongodb_mongo_master_embedded_sdk_iphoneos_10.2_9dbed1bc8108798bebc8ae7a0b56fa4858335146_18_04_23_03_32_45.tgz"
MOBILE_SDK_IPHONESIMULATOR="https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphonesimulator-10.2/9dbed1bc8108798bebc8ae7a0b56fa4858335146/mongodb_mongo_master_embedded_sdk_iphonesimulator_10.2_9dbed1bc8108798bebc8ae7a0b56fa4858335146_18_04_23_03_32_45.tgz"

# helper functions
download_mobile_sdk() {
  local target=$1 url=$2

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

# download module definitions for libmongoc/libbson
[[ -d Sources/libbson ]] || git clone --depth 1 https://github.com/mongodb/swift-bson Sources/libbson
[[ -d Sources/libmongoc ]] || git clone --depth 1 https://github.com/mongodb/swift-mongoc Sources/libmongoc

# vendor in MongoSwift
if [ ! -d Sources/MongoSwift ]; then
  curl -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball > mongo-swift.tgz
  mkdir mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1
  cp -r mongo-swift/Sources/MongoSwift Sources/MongoSwift
  # TODO: copy tests

  rm -rf mongo-swift mongo-swift.tgz
fi

# download mobile SDKs
mkdir -p MobileSDKs && cd MobileSDKs

if [ ! -d iphoneos ]; then
  download_mobile_sdk "iphoneos-tmp" $MOBILE_SDK_IPHONEOS
  fix_mongoc_symlinks "iphoneos-tmp"

  download_mobile_sdk "iphonesimulator-tmp" $MOBILE_SDK_IPHONESIMULATOR
  fix_mongoc_symlinks "iphonesimulator-tmp"

  # create shared include path
  cp -r iphoneos-tmp/include .

  # create combined SDK library paths
  mkdir -p iphoneos/lib

  echo "merging architectures into universal dylibs..."
  for lib in iphoneos-tmp/lib/*.dylib; do
    base_lib=$(basename "$lib")
    lipo iphoneos-tmp/lib/${base_lib} iphonesimulator-tmp/lib/${base_lib} -output iphoneos/lib/${base_lib} -create
  done

  # cleanup
  rm -rf iphoneos-tmp
  rm -rf iphonesimulator-tmp
fi
