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

    spec.source = {
      :git => "https://github.com/jsflax/stitch-ios-sdk.git",
      :branch => "Frameworkify",
      # :tag => '4.0.0'
    }

    spec.prepare_command = <<-CMD
      sh scripts/download_mongoswift.sh;
      python scripts/build_frameworks.py;
    CMD

    spec.platform = :ios, "11.0"
    spec.platform = :tvos, "10.2"
    spec.platform = :watchos, "4.3"
    spec.platform = :macos, "10.10"

    spec.pod_target_xcconfig = { "ENABLE_BITCODE" => "NO" }
    spec.user_target_xcconfig = {
      'FRAMEWORK_SEARCH_PATHS' => "$(PODS_ROOT)/#{spec.name}/Frameworks/ios"
    }
    spec.ios.deployment_target = "11.3"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    spec.macos.deployment_target = "10.10"

    spec.ios.vendored_frameworks = 'Frameworks/ios/*.framework'
    spec.tvos.vendored_frameworks = 'Frameworks/tvos/*.framework'
    spec.watchos.vendored_frameworks = 'Frameworks/watchos/*.framework'
    spec.macos.vendored_frameworks = 'Frameworks/macos/*.framework'
    
    spec.source_files = "Core/#{spec.name}/Sources/#{spec.name}/**/*.swift"
end
