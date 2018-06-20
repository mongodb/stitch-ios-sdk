Pod::Spec.new do |spec|
    spec.name       = File.basename(__FILE__, '.podspec')
    spec.version    = "4.0.0-beta-1"
    spec.summary    = "#{__FILE__} Module"
    spec.homepage   = "https://github.com/mongodb/stitch-ios-sdk"
    spec.license    = "Apache2"
    spec.authors    = {
      "Jason Flax" => "jason.flax@mongodb.com",
      "Adam Chelminski" => "adam.chelminski@mongodb.com",
      "Eric Daniels" => "eric.daniels@mongodb.com",
    }
    spec.platform = :ios, "11.0"
    spec.source     = {
      :git => "https://github.com/mongodb/stitch-ios-sdk.git",
      :branch => "master",
      :submodules => true
    }
  
    spec.ios.deployment_target = "11.0"
    spec.swift_version = "4.1"
    spec.requires_arc = true
    
    spec.prepare_command = "sh prep_pods.sh --module=#{spec.name} --sources=#{spec.name}"
  
    spec.source_files = "dist/#{spec.name}/**/*.swift"

    spec.dependency 'StitchCore', '~> 4.0.0-beta-1'
    spec.dependency 'StitchCoreAWSS3Service', '~> 4.0.0-beta-1'
end
