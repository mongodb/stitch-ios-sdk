Pod::Spec.new do |spec|
    spec.name       = "StitchSDK"
    spec.version    = "6.4.0"
    spec.summary    = "Stitch"
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
      :branch => "master", :tag => "6.4.0",
      :submodules => true
    }

    spec.ios.deployment_target = "11.0"

    spec.default_subspec = 'StitchSDK'

    # pod "StitchSDK/StitchCoreSDK", "~> 4.0"
    spec.subspec "StitchCoreSDK" do |core|
        core.dependency "StitchCoreSDK", "= 6.4.0"
    end

    # pod "StitchSDK/StitchCoreAWSService", "~> 4.0"
    spec.subspec "StitchCoreAWSService" do |core_aws_service|
        core_aws_service.dependency 'StitchCoreAWSService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchCoreHTTPService", "~> 4.0"
    spec.subspec "StitchCoreHTTPService" do |core_http_service|
        core_http_service.dependency 'StitchCoreHTTPService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchCoreRemoteMongoDBService", "~> 4.0"
    spec.subspec "StitchCoreRemoteMongoDBService" do |core_remote_mongodb_service|
        core_remote_mongodb_service.dependency 'StitchCoreRemoteMongoDBService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchCoreTwilioService", "~> 4.0"
    spec.subspec "StitchCoreTwilioService" do |core_twilio_service|
        core_twilio_service.dependency 'StitchCoreTwilioService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchCore", "~> 4.0"
    spec.subspec "StitchCore" do |ios_core|
        ios_core.dependency 'StitchCoreSDK', '= 6.4.0'
    end

    # pod "StitchSDK/StitchAWSService", "~> 4.0"
    spec.subspec "StitchAWSService" do |aws_service|
        aws_service.dependency 'StitchAWSService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchHTTPService", "~> 4.0"
    spec.subspec "StitchHTTPService" do |http_service|
        http_service.dependency 'StitchHTTPService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchRemoteMongoDBService", "~> 4.0"
    spec.subspec "StitchRemoteMongoDBService" do |remote_mongodb_service|
        remote_mongodb_service.dependency 'StitchRemoteMongoDBService', '= 6.4.0'
    end

    # pod "StitchSDK/StitchTwilioService", "~> 4.0"
    spec.subspec "StitchTwilioService" do |twilio_service|
        twilio_service.dependency 'StitchTwilioService', '= 6.4.0'
    end

     # pod "StitchSDK/StitchFCMService", "~> 4.0"
    spec.subspec "StitchFCMService" do |fcm_service|
        fcm_service.dependency 'StitchFCMService', '= 6.4.0'
    end

    # pod "StitchSDK", "~> 4.0"
    spec.subspec "StitchSDK" do |stitchSDK|
        stitchSDK.dependency "StitchSDK/StitchRemoteMongoDBService"
    end
end
