
  
Pod::Spec.new do |spec|
  spec.name       = "StitchSDK"
  spec.version    = "4.0.0-beta0"
  spec.summary    = "Stitch"
  spec.homepage   = "https://github.com/jsflax/stitch-ios-sdk"
  spec.license    = "Apache2"
  spec.authors    = {
    "Adam Chelminski" => "adam.chelminski@mongodb.com",
    "Jason Flax" => "jason.flax@mongodb.com",
    "Eric Daniels" => "eric.daniels@mongodb.com"
  }
  spec.platform = :ios, "8.0"
  spec.source     = {
    :git => "https://github.com/jsflax/stitch-ios-sdk.git",
    :branch => "TestLove",
    :submodules => true
  }
  spec.static_framework = true

  spec.ios.deployment_target = "11.3"
  spec.swift_version = "4.1"
  spec.requires_arc = true
  # spec.default_subspec = 'StitchSDK'
  
  spec.prepare_command = 'sh build.sh; sh prep_pods.sh;'

  PP ||= [
    "Sources/mongo_embedded/*.{h,modulemap}",
    "Sources/libbson/*.{h,modulemap}",
    "Sources/libmongoc/*.{h,modulemap}",
    "MobileSDKs"
  ]

  IOS_VL ||= ["MobileSDKs/iphoneos/lib/libmongoc-1.0.dylib", "MobileSDKs/iphoneos/lib/libbson-1.0.dylib"]
  TVOS_VL ||= ["MobileSDKs/iphoneos/lib/libmongoc-1.0.dylib", "MobileSDKs/iphoneos/lib/libbson-1.0.dylib"]
  
  # PTXC ||= {
  #   'OTHER_LDFLAGS[sdk=iphoneos*]' => '-rpath $(PODS_TARGET_SRCROOT)/Frameworks',
  #   'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/Frameworks',
  #   'OTHER_LDFLAGS[sdk=appletvos*]' => '-rpath $(PODS_TARGET_SRCROOT)/Frameworks',
  #   'OTHER_LDFLAGS[sdk=appletvsimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/Frameworks',
  #   'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_TARGET_SRCROOT)/Frameworks',
  #   'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/Frameworks',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_TARGET_SRCROOT)/Frameworks',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_TARGET_SRCROOT)/Frameworks',
  
  #   'SWIFT_INCLUDE_PATHS' => [
  #     '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include"',
  #     '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/mongo/embedded-v1/"',
  #     '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libbson-1.0"',
  #     '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libmongoc-1.0"',
  #     '"$(PODS_TARGET_SRCROOT)/Sources/mongo_embedded"',
  #     '"$(PODS_TARGET_SRCROOT)/Sources/libmongoc"',
  #     '"$(PODS_TARGET_SRCROOT)/Sources/libbson"',
  #   ].join(' ')
  # }
  
  PTXC ||= {
    # 'OTHER_LDFLAGS[sdk=iphoneos*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    # 'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    # 'OTHER_LDFLAGS[sdk=appletvos*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    # 'OTHER_LDFLAGS[sdk=appletvsimulator*]' => '-rpath $(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    # 'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    # 'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/MobileSDKs/iphoneos/lib',
    # 'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
    # 'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_TARGET_SRCROOT)/MobileSDKs/appletvos/lib',
  
    'SWIFT_INCLUDE_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/mongo/embedded-v1/"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libbson-1.0"',
      '"$(PODS_TARGET_SRCROOT)/MobileSDKs/include/libmongoc-1.0"',
      '"$(PODS_TARGET_SRCROOT)/Sources/mongo_embedded"',
      '"$(PODS_TARGET_SRCROOT)/Sources/libmongoc"',
      '"$(PODS_TARGET_SRCROOT)/Sources/libbson"',
    ].join(' ')
  }

  # UTXC ||= {
  #   'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'        => '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvos*]'       => '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  #   'LIBRARY_SEARCH_PATHS[sdk=appletvsimulator*]'=> '$(PODS_ROOT)/MobileSDKs/iphoneos/lib',
  # }

  # spec.preserve_paths = PP
  # spec.ios.vendored_library = IOS_VL
  # spec.tvos.vendored_library = TVOS_VL
  # spec.pod_target_xcconfig = PTXC
  # spec.user_target_xcconfig = UTXC

  def self.configure(subspec)
    subspec.preserve_paths = PP
    subspec.pod_target_xcconfig = PTXC
    # subspec.user_target_xcconfig = UTXC
    
    subspec.exclude_files = "SDK/**/*{Exports}.swift"
  end

  # spec.subspec "StitchSDK" do |stitchSDK|
  #   # self.configure stitchSDK

  #   stitchSDK.resource_bundle = { 'fail' => 'README.md' }
  # end
  
  # private
  spec.subspec "MongoSwift" do |mongo_swift|
    self.configure mongo_swift
    mongo_swift.ios.vendored_library = IOS_VL
    mongo_swift.tvos.vendored_library = TVOS_VL

    mongo_swift.source_files = "MongoSwift/Sources/MongoSwift/**/*.swift"
  end

  # pod "StitchSDK/StitchCoreSDK", "~> 4.0"
  spec.subspec "StitchCoreSDK" do |core|
    self.configure core

    core.source_files = "SDK/StitchCoreSDK/**/*.swift"
    core.dependency "StitchSDK/MongoSwift"
  end

  # pod "StitchSDK/StitchCoreAWSS3Service", "~> 4.0"
  spec.subspec "StitchCoreAWSS3Service" do |core_aws_s3_service|
    self.configure core_aws_s3_service

    core_aws_s3_service.source_files = "SDK/StitchCoreAWSS3Service/**/*.swift"
    # core_aws_s3_service.dependency 'StitchSDK/MongoSwift'
    core_aws_s3_service.dependency 'StitchSDK/StitchCoreSDK'
  end

  # # pod "StitchSDK/core-services-aws-ses", "~> 4.0"
  # spec.subspec "core-services-aws-ses" do |sub|    
  #   self.configure_subspec sub

  #   sub.source_files = "Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService/**/*.swift"
  #   sub.dependency 'StitchSDK/mongo-swift'
  #   sub.dependency 'StitchSDK/core-sdk'
  # end

  # # pod "StitchSDK/core-services-http", "~> 4.0"
  # spec.subspec "core-services-http" do |sub|    
  #   self.configure_subspec sub

  #   sub.source_files = "Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService/**/*.swift"
  #   sub.dependency 'StitchSDK/mongo-swift'
  #   sub.dependency 'StitchSDK/core-sdk'
  # end

  # # pod "StitchSDK/core-services-mongodb-remote", "~> 4.0"
  # spec.subspec "core-services-mongodb-remote" do |sub|    
  #   self.configure_subspec sub

  #   sub.source_files = "Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService/**/*.swift"
  #   sub.dependency 'StitchSDK/mongo-swift'
  #   sub.dependency 'StitchSDK/core-sdk'
  # end

  # # pod "StitchSDK/core-services-twilio", "~> 4.0"
  # spec.subspec "core-services-twilio" do |sub|
  #   self.configure_subspec sub

  #   sub.source_files = "Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService/**/*.swift"
  #   sub.dependency 'StitchSDK/mongo-swift'
  #   sub.dependency 'StitchSDK/core-sdk'
  # end

  # spec.subspec "core-services-mongodb-local" do |isml|
  #   isml.preserve_paths = [
  #     "Sources/mongo_embedded/*.{h,modulemap}",
  #     "Sources/libbson/*.{h,modulemap}",
  #     "Sources/libmongoc/*.{h,modulemap}",
  #     "MobileSDKs/**/*",
  #     "MobileSDKs/iphoneos/lib",
  #     "MobileSDKs/iphoneos/lib/*",
  #     "frameworks/**/*",
  #   ]
  #   isml.source_files = "Core/Services/StitchCoreLocalMongoDBService/Sources/StitchCoreLocalMongoDBService/**/*.swift"
  #   isml.vendored_frameworks = [
  #     "MongoSwift.framework", 
  #     "StitchCoreSDK.framework",
  #     "StitchCore.framework"
  #   ]
  # end

  # pod "StitchSDK/ios-core", "~> 4.0"
  # spec.subspec "StitchCore" do |ios_core|
  #   self.configure ios_core

  #   ios_core.source_files = "SDK/StitchCore/**/*.swift"
    
  #   ios_core.dependency 'StitchSDK/StitchCoreSDK'
  # end

  # # pod "StitchSDK/ios-services-aws-s3", "~> 4.0"
  # spec.subspec "StitchAWSS3Service" do |sub|
  #   self.configure_subspec sub

  #   sub.source_files = "iOS/Services/StitchAWSS3Service/StitchAWSS3Service/**/*.swift"
    
  #   sub.dependency 'StitchSDK/MongoSwift'
  #   sub.dependency 'StitchSDK/StitchCoreSDK'
  #   #sub.dependency 'StitchSDK/StitchCore'
  #   sub.dependency 'StitchSDK/StitchCoreAWSS3Service'

  #   sub.vendored_frameworks = "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework"
  # end

  # # pod "StitchSDK/ios-services-aws-ses", "~> 4.0"
  # spec.subspec "ios-services-aws-ses" do |sub|
  #   self.configure_subspec sub

  #   sub.source_files = "iOS/Services/StitchAWSSESService/StitchAWSSESService/**/*.swift"

  #   sub.dependency 'StitchSDK/mongo-swift'
  #   sub.dependency 'StitchSDK/core-sdk'
  #   sub.dependency 'StitchSDK/ios-core'
  # end

  # # pod "StitchSDK/ios-services-http", "~> 4.0"
  # spec.subspec "ios-services-http" do |ish|
  #   ish.preserve_paths = [
  #     "Sources/mongo_embedded/*.{h,modulemap}",
  #     "Sources/libbson/*.{h,modulemap}",
  #     "Sources/libmongoc/*.{h,modulemap}",
  #     "MobileSDKs/**/*",
  #     "MobileSDKs/iphoneos/lib",
  #     "MobileSDKs/iphoneos/lib/*",
  #     "frameworks/**/*",
  #   ]
  #   ish.source_files = "iOS/Services/StitchHTTPService/StitchHTTPService/**/*.swift"
  #   ish.vendored_frameworks = [
  #     "MongoSwift.framework", 
  #     "StitchCoreSDK.framework",
  #     "StitchCore.framework",
  #     "StitchCoreHTTPService.framework"
  #   ]
  # end

  # # pod "StitchSDK/ios-services-mongodb-remote", "~> 4.0"
  # spec.subspec "ios-services-mongodb-remote" do |ismr|
  #   ismr.preserve_paths = [
  #     "Sources/mongo_embedded/*.{h,modulemap}",
  #     "Sources/libbson/*.{h,modulemap}",
  #     "Sources/libmongoc/*.{h,modulemap}",
  #     "MobileSDKs/**/*",
  #     "MobileSDKs/iphoneos/lib",
  #     "MobileSDKs/iphoneos/lib/*",
  #     "frameworks/**/*",
  #   ]
  #   ismr.source_files = "iOS/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService/**/*.swift"
  #   ismr.vendored_frameworks = [
  #     "MongoSwift.framework", 
  #     "StitchCoreSDK.framework",
  #     "StitchCore.framework",
  #     "StitchCoreRemoteMongoDBService.framework"
  #   ]
  # end

  # # pod "StitchSDK/ios-services-twilio", "~> 4.0"
  # spec.subspec "ios-services-twilio" do |ist|
  #   ist.preserve_paths = [
  #     "Sources/mongo_embedded/*.{h,modulemap}",
  #     "Sources/libbson/*.{h,modulemap}",
  #     "Sources/libmongoc/*.{h,modulemap}",
  #     "MobileSDKs/**/*",
  #     "MobileSDKs/iphoneos/lib",
  #     "MobileSDKs/iphoneos/lib/*",
  #     "frameworks/**/*",
  #   ]
  #   ist.source_files = "iOS/Services/StitchTwilioService/StitchTwilioService/**/*.swift"
  #   ist.vendored_frameworks = [
  #     "MongoSwift.framework", 
  #     "StitchCoreSDK.framework",
  #     "StitchCore.framework",
  #     "StitchCoreTwilioService.framework"
  #   ]
  # end
  
  # spec.subspec "ios-services-mongodb-local" do |isml|
  #   isml.preserve_paths = [
  #     "Sources/mongo_embedded/*.{h,modulemap}",
  #     "Sources/libbson/*.{h,modulemap}",
  #     "Sources/libmongoc/*.{h,modulemap}",
  #     "MobileSDKs/**/*",
  #     "MobileSDKs/iphoneos/lib",
  #     "MobileSDKs/iphoneos/lib/*",
  #     "frameworks/**/*",
  #   ]
  #   isml.source_files = "iOS/Services/StitchLocalMongoDBService/StitchLocalMongoDBService/**/*.swift"
  #   isml.vendored_frameworks = [
  #     "MongoSwift.framework", 
  #     "StitchCoreSDK.framework",
  #     "StitchCore.framework",
  #     "StitchCoreLocalMongoDBService.framework"
  #   ]
  # end
  
  # pod "StitchSDK/ios-sdk", "~> 4.0"
  # spec.subspec "ios-sdk" do |sub|
  #   self.configure_subspec sub
  #   sub.source_files = "iOS/StitchSDK/StitchSDK/**/*.swift"

  #   sub.dependency "StitchSDK/mongo-swift"
  #   sub.vendored_frameworks = [
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/MongoSwift.framework", 
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreSDK.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSSESService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchAWSSESService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreAWSS3Service.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchAWSS3Service.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCore.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreTwilioService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchTwilioService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreRemoteMongoDBService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchRemoteMongoDBService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchCoreHTTPService.framework",
  #     "frameworks/data/Build/Products/Debug-iphonesimulator/StitchHTTPService.framework"
  #   ]
  # end
end
