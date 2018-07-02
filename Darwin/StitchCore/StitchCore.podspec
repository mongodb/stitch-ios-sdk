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

    spec.source     = {
      :git => "https://github.com/jsflax/stitch-ios-sdk.git",
      :branch => "Frameworkify", 
      # :tag => '4.0.0'
    }
  
    spec.platform = :ios, "11.0"
    spec.platform = :tvos, "10.2"
    spec.platform = :watchos, "4.3"
    spec.platform = :macos, "10.10"

    spec.pod_target_xcconfig = { "ENABLE_BITCODE" => "NO" }

    spec.ios.deployment_target = "11.3"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    spec.macos.deployment_target = "10.10"
  
    spec.source_files = "Darwin/#{spec.name}/#{spec.name}/**/*.swift"

    spec.dependency 'StitchCoreSDK', '~> 4.0.1'
end
