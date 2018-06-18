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
      :branch => "STITCH-1293"
    }
      
    spec.ios.deployment_target = "11.3"
    spec.swift_version = "4.1"
    spec.requires_arc = true
    
    spec.prepare_command = <<-CMD
      sh download_sdk.sh
      sh prep_pods.sh \
        --module=#{spec.name} \
        --sources=Sources/#{spec.name}
    CMD

    spec.source_files = "dist/#{spec.name}/**/*.swift"

    spec.dependency "MongoSwiftMobile", "~> 4.0.0-beta0"
end
