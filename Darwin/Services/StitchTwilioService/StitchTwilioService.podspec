Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "6.4.0"
    spec.summary    = "#{__FILE__} Module"
    spec.homepage   = "https://github.com/mongodb/stitch-ios-sdk"
    spec.license    = "Apache2"
    spec.authors    = {
      "Jason Flax" => "jason.flax@mongodb.com",
      "Adam Chelminski" => "adam.chelminski@mongodb.com",
      "Eric Daniels" => "eric.daniels@mongodb.com",
    }
    spec.source     = {
      :git => "https://github.com/mongodb/stitch-ios-sdk.git",
      :branch => "master", :tag => "6.4.0",
    }

    spec.platform = :ios, "11.0"

    spec.ios.deployment_target = "11.0"

    spec.source_files = "Darwin/Services/#{spec.name}/#{spec.name}/**/*.swift"

    spec.dependency 'StitchCore', '= 6.4.0'
    spec.dependency 'StitchCoreTwilioService', '= 6.4.0'
end
