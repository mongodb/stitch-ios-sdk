Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "4.0.0-beta-3"
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
      :branch => "PATCH_coveralls"
    }
  
    spec.pod_target_xcconfig = { "ENABLE_BITCODE" => "NO" }
    spec.ios.deployment_target = "11.0"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    
    spec.prepare_command = <<-CMD
      sh download_sdk.sh
      sh prep_pods.sh \
        --module=#{spec.name} \
        --sources=Sources/#{spec.name}
    CMD

    spec.source_files = "dist/#{spec.name}/**/*.swift"

    spec.dependency "MongoSwiftMobile", "~> 4.0.0-beta-3"
end
