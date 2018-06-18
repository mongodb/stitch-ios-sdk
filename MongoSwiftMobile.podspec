Pod::Spec.new do |spec|
    spec.name       = "MongoSwiftMobile"
    spec.version    = "4.0.0-beta0"
    spec.summary    = "MongoSwift Driver Mobile extension"
    spec.homepage   = "https://github.com/jsflax/stitch-ios-sdk"
    spec.license    = "Apache2"
    spec.authors    = {
      "Jason Flax" => "jason.flax@mongodb.com",
      "Adam Chelminski" => "adam.chelminski@mongodb.com",
      "Eric Daniels" => "eric.daniels@mongodb.com",
    }
    spec.platform = :ios, "8.0"
    spec.source     = {
      :git => "https://github.com/jsflax/stitch-ios-sdk.git",
      :branch => "STITCH-1293"
    }
  
    spec.ios.deployment_target = "11.3"
    spec.swift_version = "4.1"
    spec.requires_arc = true
    
    spec.prepare_command = "sh download_sdk.sh"
  
    spec.pod_target_xcconfig = {
      'OTHER_LDFLAGS[sdk=iphoneos*]' => '-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib',
      'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib',
      'OTHER_LDFLAGS[sdk=appletvos*]' => '-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib',
      'OTHER_LDFLAGS[sdk=appletvsimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib',
  
      'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib',
    
      'SWIFT_INCLUDE_PATHS' => [
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include"',
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libbson-1.0"',
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libmongoc-1.0"',
        '"$(PODS_TARGET_SRCROOT)/vendor/Sources/libmongoc"',
        '"$(PODS_TARGET_SRCROOT)/vendor/Sources/libbson"',
      ].join(' ')
    }
  
    spec.user_target_xcconfig = {
      'OTHER_LDFLAGS[sdk=iphoneos*]' => '-rpath $(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/iphoneos/lib',
      'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-rpath $(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/iphoneos/lib',
      'OTHER_LDFLAGS[sdk=appletvos*]' => '-rpath $(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/appletvos/lib',
      'OTHER_LDFLAGS[sdk=appletvsimulator*]' => '-rpath $(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/appletvos/lib',
  
      'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/iphoneos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/iphoneos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/appletvos/lib',
      'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_ROOT)/StitchSDK/vendor/MobileSDKs/appletvos/lib',
    }
  
    spec.preserve_paths = "vendor"
    libs = [
      "vendor/MobileSDKs/iphoneos/lib/libmongoc-1.0.dylib", 
      "vendor/MobileSDKs/iphoneos/lib/libbson-1.0.dylib"
    ]
    spec.ios.vendored_library = libs
    spec.tvos.vendored_library = libs

    spec.source_files = "vendor/Sources/MongoSwift/**/*.swift"
end
