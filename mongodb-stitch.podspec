Pod::Spec.new do |spec|
  spec.name       = "mongodb-stitch"
  spec.version    = "4.0.0-beta0"
  spec.summary    = "Stitch"
  spec.homepage   = "https://github.com/mongodb/stitch-ios-sdk"
  spec.license    = "Apache2"
  spec.authors    = {
    "Adam Chelminski" => "adam.chelminski@mongodb.com",
    "Jason Flax" => "jason.flax@mongodb.com",
    "Eric Daniels" => "eric.daniels@mongodb.com"
  }
  spec.platform = :ios, "11.3"
  spec.source     = {
    :git => "https://github.com/mongodb/stitch-ios-sdk.git",
    :branch => "v4-alpha",
    :submodules => true
  }
  spec.ios.deployment_target = "11.3"
  spec.swift_version = "4.1"
  spec.requires_arc = true
  #spec.default_subspec = 'mongodb-stitch'
  
  spec.prepare_command = 'sh build.sh'
  spec.preserve_paths = [
    "Sources/mongo_embedded/*.{h,modulemap}",
    "Sources/libbson/*.{h,modulemap}",
    "Sources/libmongoc/*.{h,modulemap}",
    "MobileSDKs/**/*",
    "MobileSDKs/iphoneos/lib",
    "MobileSDKs/iphoneos/lib/*",
    "frameworks/**/*",
  ]

  spec.pod_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    'OTHER_LDFLAGS[sdk=appletvos*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    'OTHER_LDFLAGS[sdk=appletvsimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',

    'SWIFT_INCLUDE_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/mongo/embedded-v1/"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libbson-1.0"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libmongoc-1.0"',
      '"$(PODS_TARGET_SRCROOT)/Sources/mongo_embedded"',
      '"$(PODS_TARGET_SRCROOT)/Sources/libmongoc"',
      '"$(PODS_TARGET_SRCROOT)/Sources/libbson"',
    ].join(' '),

    "FRAMEWORK_SEARCH_PATHS" => ["$(PODS_TARGET_SRCROOT)/frameworks"].join(" ")
  }
  
  #spec.ios.xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/fmks"' }

  #This is due to some linking leakage, should be resolved by converting to Frameworks
  # spec.user_target_xcconfig = {
  #   'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_ROOT)/MobileSDKs/appletvos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_ROOT)/MobileSDKs/appletvos/lib',
  # }

  # spec.subspec "mongodb-stitch" do |s|
  #   s.resource_bundle = { 'fail' => 'pod_fail.sh' }
  # end

  # pod "mongodb-stitch/core", "~> 4.0"
  spec.subspec "core-sdk" do |c|  
    c.source_files = "Core/StitchCoreSDK/Sources/StitchCoreSDK/**/*.swift"
    c.vendored_frameworks = "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework"
  end

  # pod "mongodb-stitch/core-services-aws-s3", "~> 4.0"
  spec.subspec "core-services-aws-s3" do |csas|
    csas.source_files = "Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service/**/*.swift"
    csas.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  # pod "mongodb-stitch/core-services-aws-ses", "~> 4.0"
  spec.subspec "core-services-aws-ses" do |csas|    
    csas.source_files = "Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService/**/*.swift"
    csas.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  # pod "mongodb-stitch/core-services-http", "~> 4.0"
  spec.subspec "core-services-http" do |csh|    
    csh.source_files = "Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService/**/*.swift"
    csh.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  # pod "mongodb-stitch/core-services-mongodb-remote", "~> 4.0"
  spec.subspec "core-services-mongodb-remote" do |csmr|    
    csmr.source_files = "Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService/**/*.swift"
    csmr.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  # pod "mongodb-stitch/core-services-twilio", "~> 4.0"
  spec.subspec "core-services-twilio" do |cst|
    cst.source_files = "Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService/**/*.swift"
    cst.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  spec.subspec "core-services-mongodb-local" do |isml|
    isml.source_files = "Core/Services/StitchCoreLocalMongoDBService/Sources/StitchCoreLocalMongoDBService/**/*.swift"
    isml.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework"
    ]
  end

  # pod "mongodb-stitch/ios-core", "~> 4.0"
  spec.subspec "ios-core" do |ic|
    ic.source_files = "iOS/StitchCore/StitchCore/**/*.swift"
    ic.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework"
    ]
  end

  # pod "mongodb-stitch/ios-services-aws-s3", "~> 4.0"
  spec.subspec "ios-services-aws-s3" do |isas|
    isas.source_files = "iOS/Services/StitchAWSS3Service/StitchAWSS3Service/**/*.swift"
    isas.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSS3Service.framework"
    ]
  end

  # pod "mongodb-stitch/ios-services-aws-ses", "~> 4.0"
  spec.subspec "ios-services-aws-ses" do |isas|
    isas.source_files = "iOS/Services/StitchAWSSESService/StitchAWSSESService/**/*.swift"
    isas.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSSESService.framework"
    ]
  end

  # pod "mongodb-stitch/ios-services-http", "~> 4.0"
  spec.subspec "ios-services-http" do |ish|
    ish.source_files = "iOS/Services/StitchHTTPService/StitchHTTPService/**/*.swift"
    ish.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreHTTPService.framework"
    ]
  end

  # pod "mongodb-stitch/ios-services-mongodb-remote", "~> 4.0"
  spec.subspec "ios-services-mongodb-remote" do |ismr|
    ismr.source_files = "iOS/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService/**/*.swift"
    ismr.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreRemoteMongoDBService.framework"
    ]
  end

  # pod "mongodb-stitch/ios-services-twilio", "~> 4.0"
  spec.subspec "ios-services-twilio" do |ist|
    ist.source_files = "iOS/Services/StitchTwilioService/StitchTwilioService/**/*.swift"
    ist.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreTwilioService.framework"
    ]
  end
  
  spec.subspec "ios-services-mongodb-local" do |isml|
    isml.source_files = "iOS/Services/StitchLocalMongoDBService/StitchLocalMongoDBService/**/*.swift"
    isml.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreLocalMongoDBService.framework"
    ]
  end
  
  # pod "mongodb-stitch/ios-sdk", "~> 4.0"
  spec.subspec "ios-sdk" do |sdk|
    sdk.vendored_frameworks = [
      "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSSESService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchAWSSESService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSS3Service.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchAWSS3Service.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreTwilioService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchTwilioService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreRemoteMongoDBService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchRemoteMongoDBService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreHTTPService.framework",
      "frameworks/data/Build/Products/Debug-iphonesimulator/StitchHTTPService.framework"
    ]
  end
end
