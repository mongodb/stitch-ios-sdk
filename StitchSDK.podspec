Pod::Spec.new do |spec|
  spec.name       = "StitchSDK"
  spec.version    = "4.0.0-beta0"
  spec.summary    = "Stitch"
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
  spec.default_subspec = 'StitchSDK'

  # pod "StitchSDK/StitchCoreSDK", "~> 4.0"
  spec.subspec "StitchCoreSDK" do |core|
    #   self.configure core

    #   core.source_files = "dist/StitchCoreSDK/**/*.swift"

      core.dependency "StitchCoreSDK", "~> 4.0.0-beta0"
  end

  # pod "StitchSDK/StitchCoreAWSS3Service", "~> 4.0"
  spec.subspec "StitchCoreAWSS3Service" do |core_aws_s3_service|
    #   self.configure core_aws_s3_service

    #   core_aws_s3_service.source_files = "dist/StitchCoreAWSS3Service/**/*.swift"

      core_aws_s3_service.dependency 'StitchCoreAWSS3Service', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchCoreAWSSESService", "~> 4.0"
  spec.subspec "StitchCoreAWSSESService" do |core_aws_ses_service|    
    #   self.configure core_aws_ses_service

    #   core_aws_ses_service.source_files = "dist/StitchCoreAWSSESService/**/*.swift"

    core_aws_ses_service.dependency 'StitchCoreAWSSESService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchCoreHTTPService", "~> 4.0"
  spec.subspec "StitchCoreHTTPService" do |core_http_service|    
    #   self.configure core_http_service

    #   core_http_service.source_files = "dist/StitchCoreHTTPService/**/*.swift"

    core_http_service.dependency 'StitchCoreHTTPService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchCoreRemoteMongoDBService", "~> 4.0"
  spec.subspec "StitchCoreRemoteMongoDBService" do |core_remote_mongodb_service|    
    #   self.configure core_remote_mongodb_service

    #   core_remote_mongodb_service.source_files = "dist/StitchCoreRemoteMongoDBService/**/*.swift"

    core_remote_mongodb_service.dependency 'StitchCoreRemoteMongoDBService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchCoreTwilioService", "~> 4.0"
    spec.subspec "StitchCoreTwilioService" do |core_twilio_service|
    #   self.configure core_twilio_service

    #   core_twilio_service.source_files = "dist/StitchCoreTwilioService/**/*.swift"

      core_twilio_service.dependency 'StitchCoreTwilioService', '~> 4.0.0-beta0'
    end

  # pod "StitchSDK/StitchCoreLocalMongoDBService", "~> 4.0"
  spec.subspec "StitchCoreLocalMongoDBService" do |core_local_mongodb_service|
    #   libs = "MobileSDKs/iphoneos/lib/*.dylib"

    #   core_local_mongodb_service.ios.vendored_library = libs
    #   core_local_mongodb_service.tvos.vendored_library = libs

    #   core_local_mongodb_service.source_files = "dist/StitchCoreLocalMongoDBService/**/*.swift"

      core_local_mongodb_service.dependency 'StitchCoreLocalMongoDBService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchCore", "~> 4.0"
  spec.subspec "StitchCore" do |ios_core|
    #   self.configure ios_core

    #   ios_core.source_files = "dist/StitchCore/**/*.swift"
      ios_core.dependency 'StitchCoreSDK', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchAWSS3Service", "~> 4.0"
  spec.subspec "StitchAWSS3Service" do |aws_s3_service|
    #   self.configure aws_s3_service

    #   aws_s3_service.source_files = "dist/StitchAWSS3Service/**/*.swift"
      
    #   aws_s3_service.dependency 'StitchSDK/StitchCore'
      aws_s3_service.dependency 'StitchAWSS3Service', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchAWSSESService", "~> 4.0"
  spec.subspec "StitchAWSSESService" do |aws_ses_service|
    #   self.configure aws_ses_service

    #   aws_ses_service.source_files = "dist/StitchAWSSESService/**/*.swift"

    #   aws_ses_service.dependency 'StitchSDK/StitchCore'
      aws_ses_service.dependency 'StitchAWSSESService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchHTTPService", "~> 4.0"
  spec.subspec "StitchHTTPService" do |http_service|
    #   self.configure http_service

    #   http_service.source_files = "dist/StitchHTTPService/**/*.swift"

    #   http_service.dependency 'StitchSDK/StitchCore'
      http_service.dependency 'StitchHTTPService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchRemoteMongoDBService", "~> 4.0"
  spec.subspec "StitchRemoteMongoDBService" do |remote_mongodb_service|
    #   self.configure remote_mongodb_service

    #   remote_mongodb_service.source_files = "dist/StitchRemoteMongoDBService/**/*.swift"

    #   remote_mongodb_service.dependency 'StitchSDK/StitchCore'
      remote_mongodb_service.dependency 'StitchRemoteMongoDBService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchTwilioService", "~> 4.0"
  spec.subspec "StitchTwilioService" do |twilio_service|
    #   self.configure twilio_service

    #   twilio_service.source_files = "dist/StitchTwilioService/**/*.swift"

    #   twilio_service.dependency 'StitchSDK/StitchCore'
      twilio_service.dependency 'StitchTwilioService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchLocalMongoDBService", "~> 4.0"
  spec.subspec "StitchLocalMongoDBService" do |local_mongodb_service|
    #   self.configure local_mongodb_service

    #   local_mongodb_service.source_files = "dist/StitchLocalMongoDBService/**/*.swift"

    #   local_mongodb_service.dependency 'StitchSDK/StitchCore'
      local_mongodb_service.dependency 'StitchLocalMongoDBService', '~> 4.0.0-beta0'
  end

  # pod "StitchSDK/StitchSDK", "~> 4.0"
  spec.subspec "StitchSDK" do |stitchSDK|
      # self.configure stitchSDK

    # stitchSDK.dependency "StitchSDK/StitchCore"
    #   stitchSDK.dependency "StitchSDK/StitchCoreRemoteMongoDBService"
      stitchSDK.dependency "StitchSDK/StitchRemoteMongoDBService"
  end
end
