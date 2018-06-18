Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "4.0.0-beta0"
    spec.summary    = "#{__FILE__} Module"
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
      :branch => "STITCH-1293",
      :submodules => true
    }

    spec.ios.deployment_target = "11.3"
    spec.swift_version = "4.1"
    spec.requires_arc = true
    
    spec.prepare_command = <<-CMD
      sh download_sdk.sh --with_mobile
      sh prep_pods.sh \
        --module=#{spec.name} \
        --sources=Sources/#{spec.name}
    CMD

    spec.pod_target_xcconfig = {
      'SWIFT_INCLUDE_PATHS' => [
        '"$(PODS_TARGET_SRCROOT)/vendor/MobileSDKs/include/mongo/embedded-v1/"',
        '"$(PODS_TARGET_SRCROOT)/vendor/Sources/mongo_embedded"'
      ].join(' ')
    }
    
    spec.preserve_paths = "vendor"
  
    spec.source_files = "dist/#{spec.name}/**/*.swift"

    libs = "vendor/MobileSDKs/iphoneos/lib/lib*[^bson-1.0][^mongoc-1.0].dylib"
    spec.ios.vendored_library = libs
    spec.tvos.vendored_library = libs

    spec.dependency 'StitchCoreSDK', '~> 4.0.0-beta0'
end
