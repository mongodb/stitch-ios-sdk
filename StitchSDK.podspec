Pod::Spec.new do |spec|
    spec.name       = "StitchSDK"
    spec.version    = "4.0.0"
    spec.summary    = "Stitch"
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
      :git => "https://github.com/mongodb/stitch-ios-sdk.git",
      :branch => "master",
      :tag => '4.0.0',
      :submodules => true
    }
  
    spec.pod_target_xcconfig = { "ENABLE_BITCODE" => "NO" }
    spec.ios.deployment_target = "11.0"
    spec.tvos.deployment_target = "10.2"
    spec.watchos.deployment_target = "4.3"
    spec.default_subspec = 'StitchSDK'
  
    # pod "StitchSDK/StitchCoreSDK", "~> 4.0"
    spec.subspec "StitchCoreSDK" do |core|
        core.dependency "StitchCoreSDK", "~> 4.0.0"
    end

    # pod "StitchSDK/StitchCoreAWSS3Service", "~> 4.0"
    spec.subspec "StitchCoreAWSS3Service" do |core_aws_s3_service|
        core_aws_s3_service.dependency 'StitchCoreAWSS3Service', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchCoreAWSSESService", "~> 4.0"
    spec.subspec "StitchCoreAWSSESService" do |core_aws_ses_service|    
        core_aws_ses_service.dependency 'StitchCoreAWSSESService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchCoreHTTPService", "~> 4.0"
    spec.subspec "StitchCoreHTTPService" do |core_http_service|
        core_http_service.dependency 'StitchCoreHTTPService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchCoreRemoteMongoDBService", "~> 4.0"
    spec.subspec "StitchCoreRemoteMongoDBService" do |core_remote_mongodb_service|
        core_remote_mongodb_service.dependency 'StitchCoreRemoteMongoDBService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchCoreTwilioService", "~> 4.0"
        spec.subspec "StitchCoreTwilioService" do |core_twilio_service|
        core_twilio_service.dependency 'StitchCoreTwilioService', '~> 4.0.0'
        end

    # pod "StitchSDK/StitchCoreLocalMongoDBService", "~> 4.0"
    spec.subspec "StitchCoreLocalMongoDBService" do |core_local_mongodb_service|
        core_local_mongodb_service.dependency 'StitchCoreLocalMongoDBService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchCore", "~> 4.0"
    spec.subspec "StitchCore" do |ios_core|
        ios_core.dependency 'StitchCoreSDK', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchAWSS3Service", "~> 4.0"
    spec.subspec "StitchAWSS3Service" do |aws_s3_service|
        aws_s3_service.dependency 'StitchAWSS3Service', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchAWSSESService", "~> 4.0"
    spec.subspec "StitchAWSSESService" do |aws_ses_service|
        aws_ses_service.dependency 'StitchAWSSESService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchHTTPService", "~> 4.0"
    spec.subspec "StitchHTTPService" do |http_service|
        http_service.dependency 'StitchHTTPService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchRemoteMongoDBService", "~> 4.0"
    spec.subspec "StitchRemoteMongoDBService" do |remote_mongodb_service|
        remote_mongodb_service.dependency 'StitchRemoteMongoDBService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchTwilioService", "~> 4.0"
    spec.subspec "StitchTwilioService" do |twilio_service|
        twilio_service.dependency 'StitchTwilioService', '~> 4.0.0'
    end

    # pod "StitchSDK/StitchLocalMongoDBService", "~> 4.0"
    spec.subspec "StitchLocalMongoDBService" do |local_mongodb_service|
        local_mongodb_service.dependency 'StitchLocalMongoDBService', '~> 4.0.0'
    end

    # pod "StitchSDK", "~> 4.0"
    spec.subspec "StitchSDK" do |stitchSDK|
        stitchSDK.dependency "StitchSDK/StitchRemoteMongoDBService"
    end
end
