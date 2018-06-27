Pod::Spec.new do |spec|
    spec.name       = "MongoSwiftMobile"
    spec.version    = "4.0.1"
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
    # spec.tvos.deployment_target = "10.2"
    # spec.watchos.deployment_target = "4.3"
    
    spec.prepare_command = "sh scripts/download_frameworks.sh; sh scripts/download_mongoswift.sh"
    
    spec.pod_target_xcconfig = {
      'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Frameworks/libbson.framework/Frameworks $(PODS_TARGET_SRCROOT)/Frameworks/libmongoc.framework/Frameworks',
    }
  
    spec.user_target_xcconfig = { 
      'LIBRARY_SEARCH_PATHS' => '$(PODS_ROOT)/MongoSwiftMobile/Frameworks/libbson.framework/Frameworks $(PODS_TARGET_SRCROOT)/Frameworks/libmongoc.framework/Frameworks',
    }
    

    spec.vendored_frameworks = ['Frameworks/libmongoc.framework', 'Frameworks/libbson.framework']
    spec.source_files = "Sources/MongoSwift/**/*.swift"

    # spec.dependency 'libbson', '~> 0.0.1'

    # spec.dependency 'libmongoc', '~> 0.0.14'
end
