Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "4.0.0-beta-2"
    spec.summary    = "#{__FILE__} Module"
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
      :git => "https://github.com/jsflax/stitch-ios-sdk.git",
      :branch => "master"
    }
  
    spec.ios.deployment_target = "11.0"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    
    spec.prepare_command = <<-CMD
      sh download_sdk.sh --with-mobile
      sh prep_pods.sh \
        --module=#{spec.name} \
        --sources=Sources/#{spec.name}
    CMD

    spec.pod_target_xcconfig = {
      'SWIFT_INCLUDE_PATHS' => [
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/mongo/embedded-v1/"',
        '"$(PODS_TARGET_SRCROOT)/vendor/Sources/mongo_embedded"'
      ].join(' '),
      "ENABLE_BITCODE" => "NO"
    }
    
    spec.preserve_paths = "vendor"
  
    spec.source_files = "dist/#{spec.name}/**/*.swift"

    def self.vendor_path(platform)
      Dir.entries("vendor/MobileSDKs/#{platform}/lib/").select {
        |f| ![
          "libbson-1.0.0.0.0.dylib", 
          "libbson-1.0.dylib", 
          "libmongoc-1.0.0.dylib", 
          "libbson-1.0.0.dylib", 
          "libmongoc-1.0.0.0.0.dylib", 
          "libmongoc-1.0.dylib"
        ].any? { |lib| f.include?(lib) }
      }.map { |lib| "vendor/MobileSDKs/#{platform}/lib/#{lib}" }
    end
    
    spec.ios.vendored_library = self.vendor_path "iphoneos"
    spec.tvos.vendored_library = self.vendor_path "appletvos"
    spec.watchos.vendored_library = self.vendor_path "watchos"

    spec.dependency 'StitchCoreSDK', '~> 4.0.0-beta-3'
end
