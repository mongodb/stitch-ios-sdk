Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "4.0.1"
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
      :git => "https://github.com/mongodb/stitch-ios-sdk.git",
      :branch => "master", 
      :tag => '4.0.0'
    }
  
    spec.ios.deployment_target = "11.0"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    
    spec.prepare_command = <<-CMD
      sh scripts/download_sdk.sh --with-mobile --for-pods
      sh scripts/prep_pods.sh \
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
    
    spec.ios.vendored_library = 'vendor/MobileSDKs/iphoneos/lib/*.dylib'
    spec.tvos.vendored_library = 'vendor/MobileSDKs/appletvos/lib/*.dylib'
    spec.watchos.vendored_library = 'vendor/MobileSDKs/watchos/lib/*.dylib'

    spec.dependency 'StitchCoreSDK', '<= 4.0.0'
end
