#!/bin/bash

# helper functions
# log info
log_i() {
    printf "\033[1;36m$1\033[0m\n"
}
# log warn
log_w() {
    printf "\033[1;33m$1\033[0m\n"
}
# log error
log_e() {
    printf "\033[1;31m$1\033[0m\n"
}
# get sdk url for variange
mobile_sdk_url() {
  local variant=$1

  case "$variant" in
    iphoneos)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphoneos-10.2/4c77f4f5a72a27ac98557de49b74eb1a019dd196/mongodb_mongo_master_embedded_sdk_iphoneos_10.2_patch_4c77f4f5a72a27ac98557de49b74eb1a019dd196_5b294ecae3c3312e46f5028e_18_06_19_18_43_41.tgz"
      ;;
    iphonesimulator)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-iphonesimulator-10.2/4c77f4f5a72a27ac98557de49b74eb1a019dd196/mongodb_mongo_master_embedded_sdk_iphonesimulator_10.2_patch_4c77f4f5a72a27ac98557de49b74eb1a019dd196_5b294ecae3c3312e46f5028e_18_06_19_18_43_41.tgz"
      ;;
    appletvos)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-appletvos-10.2/4c77f4f5a72a27ac98557de49b74eb1a019dd196/mongodb_mongo_master_embedded_sdk_appletvos_10.2_patch_4c77f4f5a72a27ac98557de49b74eb1a019dd196_5b294ecae3c3312e46f5028e_18_06_19_18_43_41.tgz"
      ;;
    appletvsimulator)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-appletvsimulator-10.2/4c77f4f5a72a27ac98557de49b74eb1a019dd196/mongodb_mongo_master_embedded_sdk_appletvsimulator_10.2_patch_4c77f4f5a72a27ac98557de49b74eb1a019dd196_5b294ecae3c3312e46f5028e_18_06_19_18_43_41.tgz"
      ;;
    watchos)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-watchos-4.2/32d04037b7b37ed68925b21b24dbd8e032ea7b48/mongodb_mongo_master_embedded_sdk_watchos_4.2_32d04037b7b37ed68925b21b24dbd8e032ea7b48_18_06_19_19_46_02.tgz"
      ;;
    watchsimulator)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-master/embedded-sdk/embedded-sdk-watchsimulator-4.2/32d04037b7b37ed68925b21b24dbd8e032ea7b48/mongodb_mongo_master_embedded_sdk_watchsimulator_4.2_32d04037b7b37ed68925b21b24dbd8e032ea7b48_18_06_19_19_46_02.tgz"
      ;;
    macos)
      echo "https://s3.amazonaws.com/mciuploads/mongodb-mongo-v4.0/embedded-sdk/embedded-sdk-macosx-10.10-latest.tgz"
      ;;
  esac
}

# download mobile sdk for target from url
download_mobile_sdk() {
  local target=$1 url=$2
  log_i "downloading to $1"
  curl -# $url > mobile-sdks.tgz
  mkdir $target
  tar -xzf mobile-sdks.tgz -C $target --strip-components 2
  rm mobile-sdks.tgz
}

# fix 1.0.0 -> 1.0 links
fix_mongoc_symlinks() {
  local prefix=$1

  rm $prefix/lib/libbson-1.0.dylib
  cp $prefix/lib/libbson-1.0.0.dylib $prefix/lib/libbson-1.0.dylib
  rm $prefix/lib/libmongoc-1.0.dylib
  cp $prefix/lib/libmongoc-1.0.0.dylib $prefix/lib/libmongoc-1.0.dylib
}

# download and lipo each variant
download_and_combine() {
  local variant=$1
  local variant_os=${variant}os
  local variant_os_tmp=${variant_os}-tmp
  local variant_simulator=${variant}simulator
  local variant_simulator_tmp=${variant_simulator}-tmp

  if [ ! -d $variant_os ]; then
    local os_url=$(mobile_sdk_url ${variant_os})
    if [[ ! -z $os_url ]]; then
      download_mobile_sdk $variant_os_tmp $os_url
      fix_mongoc_symlinks $variant_os_tmp
    fi

    local sim_url=$(mobile_sdk_url ${variant_simulator})
    if [[ ! -z $sim_url ]]; then
      download_mobile_sdk $variant_simulator_tmp $sim_url
      fix_mongoc_symlinks $variant_simulator_tmp
    fi

    # create shared include path
    cp -r $variant_os_tmp/include .

    # create combined SDK library paths
    mkdir -p ${variant_os}/lib

    log_i "merging $variant_os architectures into universal dylibs..."
    tmp_libs=`[[ $WITH_MOBILE == YES ]] && echo $variant_os_tmp/lib/*.dylib || find -E ./$variant_os_tmp/lib -type f -regex ".*lib(bson|mongoc)-.*.dylib"`
    for lib in $tmp_libs; do
      local base_lib=$(basename "$lib")
      lipo $variant_os_tmp/lib/${base_lib} \
        `[[ ! -z $sim_url ]] && echo $variant_simulator_tmp/lib/${base_lib}` \
        -output ${variant_os}/lib/${base_lib} \
        -create
    done;

    # cleanup
    rm -rf $variant_os_tmp
    rm -rf $variant_simulator_tmp
  fi
}

mkdir -p vendor && cd vendor

POSITIONAL=()
# with MongoMobile
WITH_MOBILE=NO
# should also run make
SHOULD_MAKE=NO
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -wM|--with-mobile)
    WITH_MOBILE=YES
    shift # past argument
    shift # past value
    ;;
    -m|--make)
    SHOULD_MAKE=YES
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# download module definitions for libmongoc/libbson
[[ -d Sources/libbson ]] || git clone --depth 1 https://github.com/mongodb/swift-bson Sources/libbson
[[ -d Sources/libmongoc ]] || git clone --depth 1 https://github.com/mongodb/swift-mongoc Sources/libmongoc

# download MongoSwift
if [ ! -d Sources/MongoSwift ]; then
  log_i "downloading MongoSwift"
  curl -# -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball > mongo-swift.tgz
  mkdir mongo-swift
  # extract mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1
  # copy it to vendored Sources dir
  cp -r mongo-swift/Sources/MongoSwift Sources/MongoSwift
  # remove artifacts
  rm -rf mongo-swift mongo-swift.tgz
else
  log_w "skipping downloading MongoSwift"
fi

# download mobile SDKs
if [ ! -d MobileSDKs ]; then
    log_i "downloading MobileSDKs"

    mkdir -p MobileSDKs && cd MobileSDKs
    download_and_combine "iphone"
    download_and_combine "appletv"
    download_and_combine "watch"
    cd ..
else
  log_w "skipping downloading MobileSDKs"
fi

# download MongoMobile
if [[ $WITH_MOBILE == YES ]]; then
  # find the StitchCoreLocalMongoDBService Sources directory
  find ../ -type d -name "StitchCoreLocalMongoDBService" -print | grep -v "dist" | while read dir; do
    # if the directory matches the Sources pattern
    if [[ $dir =~ .*Sources/StitchCoreLocalMongoDBService$ ]]; then
      # if we haven't already created the MongoMobile dir
      #if [[ ! -d $dir/MongoMobile ]]; then
        log_i "downloading MongoMobile"
        curl -L https://api.github.com/repos/mongodb/swift-mongo-mobile/tarball > mongo-mobile.tgz
        mkdir mongo-mobile
        tar -xzf mongo-mobile.tgz -C mongo-mobile --strip-components 1
        # copy MobileMongo into our Service's sources
        cp -r mongo-mobile/Sources/MongoMobile $dir
        cp -r mongo-mobile/Sources/mongo_embedded Sources/
        rm -rf mongo-mobile mongo-mobile.tgz
      break
    fi
  done
else
    log_w "skipping downloading MongoMobile"
fi

cd ..
if [[ $SHOULD_MAKE == YES && ! -d Core/StitchCoreSDK/StitchCoreSDK.xcodeproj ]]; then
    make
else
  log_w "skipping make phase"
fi

log_i "done building!";
