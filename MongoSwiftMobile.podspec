Pod::Spec.new do |spec|
    spec.name       = "MongoSwiftMobile"
    spec.version    = "4.0.3"
    spec.summary    = "MongoSwift Driver Mobile extension"
    spec.homepage   = "https://github.com/mongodb/stitch-ios-sdk"
    spec.license    = "Apache2"
    spec.authors    = {
      "Jason Flax" => "jason.flax@mongodb.com",
      "Adam Chelminski" => "adam.chelminski@mongodb.com",
      "Eric Daniels" => "eric.daniels@mongodb.com",
    }
    spec.platform = :ios, "11.3"
    # spec.platform = :tvos, "10.2"
    # spec.platform = :watchos, "4.3"

    spec.source     = {
      :git => "https://github.com/jsflax/stitch-ios-sdk.git",
      :branch => "Frameworkify", 
      # :tag => '4.0.0'
    }
  
    spec.ios.deployment_target = "11.3"
    spec.tvos.deployment_target = "10.2"
    
    spec.prepare_command = "python scripts/download_frameworks.py; sh scripts/download_mongoswift.sh"

    spec.pod_target_xcconfig = { "ENABLE_BITCODE" => "NO" }
    spec.user_target_xcconfig = { "ENABLE_BITCODE" => "NO" }

    spec.ios.vendored_frameworks = 'Frameworks/iOS/*.framework'
    spec.tvos.vendored_frameworks = 'Frameworks/tvOS/*.framework'

    spec.source_files = "Sources/MongoSwift/**/*.swift"
end
