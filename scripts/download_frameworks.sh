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

build_libbson() {
  local VARIANT=$1
  local SDK_PATH_OS=$2
  local SDK_PATH_SIM=$3
  local FRAMEWORK_PATH=$4

  FRAMEWORK_BASE_NAME=bson
  FRAMEWORK_NAME=libbson
  FRAMEWORK_BUNDLE=$FRAMEWORK_PATH/$FRAMEWORK_NAME.framework
  FRAMEWORK_VERSION=1.0.0

  echo "building $FRAMEWORK_NAME for: ${VARIANT}"
  echo "  > setting up framework directories"
  mkdir -p "$FRAMEWORK_BUNDLE"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources"

  echo "  > creating symlinks"
  ln -s "$FRAMEWORK_VERSION"               "$FRAMEWORK_BUNDLE/Versions/Current"
  ln -s "Versions/Current/Headers"         "$FRAMEWORK_BUNDLE/Headers"
  ln -s "Versions/Current/Resources"       "$FRAMEWORK_BUNDLE/Resources"
  ln -s "Versions/Current/$FRAMEWORK_NAME" "$FRAMEWORK_BUNDLE/$FRAMEWORK_NAME"

  echo "  > copying includes"
  cp -r $SDK_PATH_OS/include/$FRAMEWORK_NAME*/* "$FRAMEWORK_BUNDLE/Headers/" || exit 1
  cat > "$FRAMEWORK_BUNDLE/Headers/$FRAMEWORK_NAME.h" <<EOF
#define BCON_H_
#include "${FRAMEWORK_BASE_NAME}.h"
EOF

  echo "  > creating module map"
  mkdir -p "$FRAMEWORK_BUNDLE/Modules"
  cat > "$FRAMEWORK_BUNDLE/Modules/module.modulemap" <<EOF
framework module ${FRAMEWORK_NAME} [system] {
  umbrella header "${FRAMEWORK_NAME}.h"

  export *
  module * { export * }
}
EOF

  echo "  > lipoing libraries into framework"
  FRAMEWORK_VNAME=$FRAMEWORK_NAME-$FRAMEWORK_VERSION
  lipo -create $SDK_PATH_OS/lib/$FRAMEWORK_VNAME.dylib $SDK_PATH_SIM/lib/$FRAMEWORK_VNAME.dylib -o "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME" || exit 1

  # fix up rpaths
  install_name_tool -id @rpath/$FRAMEWORK_NAME.framework/Versions/Current/$FRAMEWORK_NAME "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME"

  echo "  > creating plist"
    cat > "$FRAMEWORK_BUNDLE/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key>
<string>${FRAMEWORK_NAME}</string>
<key>CFBundleIdentifier</key>
<string>com.mongodb</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundlePackageType</key>
<string>FMWK</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>${FRAMEWORK_VERSION}</string>
</dict>
</plist>
EOF
}

build_libmongoc() {
  local VARIANT=$1
  local SDK_PATH_OS=$2
  local SDK_PATH_SIM=$3
  local FRAMEWORK_PATH=$4

  FRAMEWORK_BASE_NAME=mongoc
  FRAMEWORK_NAME=lib$FRAMEWORK_BASE_NAME
  FRAMEWORK_BUNDLE=$FRAMEWORK_PATH/$FRAMEWORK_NAME.framework
  FRAMEWORK_VERSION=1.0.0

  echo "building $FRAMEWORK_NAME for: ${VARIANT}"
  echo "  > setting up framework directories"
  mkdir -p "$FRAMEWORK_BUNDLE"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers"
  mkdir -p "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources"

  echo "  > creating symlinks"
  ln -s "$FRAMEWORK_VERSION"               "$FRAMEWORK_BUNDLE/Versions/Current"
  ln -s "Versions/Current/Headers"         "$FRAMEWORK_BUNDLE/Headers"
  ln -s "Versions/Current/Resources"       "$FRAMEWORK_BUNDLE/Resources"
  ln -s "Versions/Current/$FRAMEWORK_NAME" "$FRAMEWORK_BUNDLE/$FRAMEWORK_NAME"

  echo "  > copying includes"
  cp -r $SDK_PATH_OS/include/$FRAMEWORK_NAME*/* "$FRAMEWORK_BUNDLE/Headers/" || exit 1
  sed -i '' -e 's/#include <bson.h>/#include <libbson\/bson.h>/g' $FRAMEWORK_BUNDLE/Headers/*.h
  cat > "$FRAMEWORK_BUNDLE/Headers/${FRAMEWORK_NAME}.h" <<EOF
#include "${FRAMEWORK_BASE_NAME}.h"
EOF

  echo "  > creating module map"
  mkdir -p "$FRAMEWORK_BUNDLE/Modules"
  cat > "$FRAMEWORK_BUNDLE/Modules/module.modulemap" <<EOF
framework module ${FRAMEWORK_NAME} [system] {
  umbrella header "${FRAMEWORK_NAME}.h"

  export *
  module * { export * }
}
EOF

  echo "  > lipoing libraries into framework"
  FRAMEWORK_VNAME=$FRAMEWORK_NAME-$FRAMEWORK_VERSION
  lipo -create $SDK_PATH_OS/lib/$FRAMEWORK_VNAME.dylib $SDK_PATH_SIM/lib/$FRAMEWORK_VNAME.dylib -o "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME" || exit 1
    codesign --remove-signature "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME"
  # fix up rpaths
  install_name_tool -id @rpath/$FRAMEWORK_NAME.framework/Versions/Current/$FRAMEWORK_NAME "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME"
  install_name_tool -change @rpath/libbson-1.0.1.dylib @rpath/libbson.framework/Versions/Current/libbson "$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME"

  echo "  > creating plist"
    cat > "$FRAMEWORK_BUNDLE/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key>
<string>${FRAMEWORK_NAME}</string>
<key>CFBundleIdentifier</key>
<string>com.mongodb</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundlePackageType</key>
<string>FMWK</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>${FRAMEWORK_VERSION}</string>
</dict>
</plist>
EOF
}

download_and_build_framework() {
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

    echo "building frameworks..."
    build_libbson $variant $variant_os_tmp $variant_simulator_tmp $variant_os
    build_libmongoc $variant $variant_os_tmp $variant_simulator_tmp $variant_os

    # cleanup
    rm -rf $variant_os_tmp
    rm -rf $variant_simulator_tmp
  fi
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
mkdir -p MobileSDKs
pushd MobileSDKs
  download_and_build_framework "iphone"
  # download_and_build_framework "appletv"
popd