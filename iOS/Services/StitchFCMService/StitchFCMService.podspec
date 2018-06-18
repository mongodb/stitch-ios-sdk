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
    
    spec.prepare_command = "sh prep_pods.sh --module=#{spec.name} --sources=#{spec.name}"

    spec.exclude_files = "dist/**/*{Exports}.swift"
  
    spec.source_files = "dist/#{spec.name}/**/*.swift"

    spec.dependency 'StitchCore', '~> 4.0.0-beta0'
    spec.dependency 'StitchCoreFCMService', '~> 4.0.0-beta0'
end
