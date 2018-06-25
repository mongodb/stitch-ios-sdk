Pod::Spec.new do |spec|
    spec.name       = "MongoSwiftMobile"
    spec.version    = "4.0.0-beta-3"
    spec.summary    = "MongoSwift Driver Mobile extension"
    spec.homepage   = "https://github.com/mongodb/stitch-ios-sdk"
    spec.license    = "Apache2"
    spec.authors    = {
      "Jason Flax" => "jason.flax@mongodb.com",
      "Adam Chelminski" => "adam.chelminski@mongodb.com",
      "Eric Daniels" => "eric.daniels@mongodb.com",
    }
    spec.platform = :ios, "11.0"
    spec.platform = :tvos, "10.2"
    spec.platform = :watchos, "4.3"

    spec.source     = {
      :git => "https://github.com/mongodb/stitch-ios-sdk.git",
      :branch => "master"
    }
  
    spec.ios.deployment_target = "11.0"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    
    spec.prepare_command = "sh scripts/download_sdk.sh"
    
    spec.pod_target_xcconfig = {
      "OTHER_LDFLAGS[sdk=iphoneos*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib",
      "OTHER_LDFLAGS[sdk=iphonesimulator*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib",
      "OTHER_LDFLAGS[sdk=appletvos*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib",
      "OTHER_LDFLAGS[sdk=appletvsimulator*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib",
      "OTHER_LDFLAGS[sdk=watchos*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/watchos/lib",
      "OTHER_LDFLAGS[sdk=watchsimulator*]" => "-rpath $(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/watchos/lib",

      "LIBRARY_SEARCH_PATHS[sdk=iphoneos*]"        => "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]" => "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/iphoneos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=appletvos*]"       => "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]"=> "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/appletvos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=watchos*]"         => "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/watchos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=watchsimulator*]"=> "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/watchos/lib",
      
      "SWIFT_INCLUDE_PATHS" => [
        "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include",
        "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libbson-1.0",
        "$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/libmongoc-1.0",
        "$(PODS_TARGET_SRCROOT)/vendor/Sources/libmongoc",
        "$(PODS_TARGET_SRCROOT)/vendor/Sources/libbson",
      ].join(" "),

      "ENABLE_BITCODE" => "NO"
    }
  
    spec.user_target_xcconfig = {
      "OTHER_LDFLAGS[sdk=iphoneos*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/iphoneos/lib",
      "OTHER_LDFLAGS[sdk=iphonesimulator*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/iphoneos/lib",
      "OTHER_LDFLAGS[sdk=appletvos*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/appletvos/lib",
      "OTHER_LDFLAGS[sdk=appletvsimulator*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/appletvos/lib",
      "OTHER_LDFLAGS[sdk=watchos*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/watchos/lib",
      "OTHER_LDFLAGS[sdk=watchsimulator*]" => "-rpath $(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/watchos/lib",

      "LIBRARY_SEARCH_PATHS[sdk=iphoneos*]"        => "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/iphoneos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]" => "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/iphoneos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=appletvos*]"       => "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/appletvos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]"=> "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/appletvos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=watchos*]"         => "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/watchos/lib",
      "LIBRARY_SEARCH_PATHS[sdk=watchsimulator*]"=> "$(PODS_ROOT)/#{spec.name}/vendor/MobileSDKs/watchos/lib",

      "ENABLE_BITCODE" => "NO"
    }
  
    spec.preserve_paths = "vendor"
    
    def self.libs(platform)
      return "vendor/MobileSDKs/#{platform}/lib/*.dylib"
    end

    spec.ios.vendored_library = self.libs "iphoneos"
    spec.tvos.vendored_library = self.libs "appletvos"
    spec.watchos.vendored_library = self.libs "watchos"

    spec.source_files = "vendor/Sources/MongoSwift/**/*.swift"
end
