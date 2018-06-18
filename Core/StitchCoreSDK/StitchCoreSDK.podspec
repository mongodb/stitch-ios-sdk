
Pod::Spec.new do |spec|
    spec.name       = "StitchCoreSDK"
    spec.version    = "4.0.0-beta0"
    spec.summary    = "Stitch Core Module"
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
      :branch => "TestLove",
      :submodules => true
    }
  
    spec.ios.deployment_target = "11.3"
    spec.swift_version = "4.1"
    spec.requires_arc = true
    
    spec.prepare_command = 'sh download_sdk.sh; sh prep_pods.sh --module=StitchCoreSDK;'
    
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
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/mongo/embedded-v1/"',
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libbson-1.0"',
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libmongoc-1.0"',
        '"$(PODS_TARGET_SRCROOT)/vendor/Sources/mongo_embedded"',
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

    spec.exclude_files = "dist/**/*{Exports}.swift"
  
    spec.source_files = ["dist/#{spec.name}/**/*.swift", "vendor/Sources/MongoSwift/**/*.swift"]
    libs = ["vendor/MobileSDKs/iphoneos/lib/libmongoc-1.0.dylib", "vendor/MobileSDKs/iphoneos/lib/libbson-1.0.dylib"]
    spec.ios.vendored_library = libs
    spec.tvos.vendored_library = libs
end
