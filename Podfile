workspace 'Stitch.xcworkspace'

platform :ios, '11.0'



target :MockUtils do
    project 'MockUtils/MockUtils.xcodeproj'
end

pod 'MongoSwift', '~> 0.0.5'

target :StitchCoreAdminClient do
    project 'Core/StitchCoreAdminClient/StitchCoreAdminClient.xcodeproj'
end

target :StitchCoreSDK do
    project 'Core/StitchCoreSDK/StitchCoreSDK.xcodeproj'

    target :StitchCoreSDKMocks do
        inherit! :search_paths
    end

    target :StitchCoreSDKTests do
        pod 'JSONWebToken', '2.2.0'
        pod 'Swifter', '1.4.5'
    end
end

target :StitchCoreTestUtils do
    project 'Core/StitchCoreTestUtils/StitchCoreTestUtils.xcodeproj'
end

target :StitchCoreTwilioService do
  project 'Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj'

  target :StitchCoreTwilioServiceTests do
    inherit! :search_paths
  end
end

target :StitchCoreRemoteMongoDBService do
  project 'Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj'

  target :StitchCoreRemoteMongoDBServiceTests do
    inherit! :search_paths
  end
end

target :StitchCoreLocalMongoDBService do
    project 'Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj'
    pod 'MongoMobile', '~> 0.0.3'

    target :StitchCoreLocalMongoDBServiceTests do
        inherit! :search_paths
    end
end

target :StitchCoreHTTPService do
    project 'Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj'

    target :StitchCoreHTTPServiceTests do
        inherit! :search_paths
    end
end

target :StitchCoreFCMService do
    project 'Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj'

    target :StitchCoreFCMServiceTests do
        inherit! :search_paths
    end
end

target :StitchCoreAWSSESService do
    project 'Core/Services/StitchCoreAWSSESService/StitchCoreAWSSESService.xcodeproj'

    target :StitchCoreAWSSESServiceTests do
        inherit! :search_paths
    end
end

target :StitchCoreAWSS3Service do
    project 'Core/Services/StitchCoreAWSS3Service/StitchCoreAWSS3Service.xcodeproj'

    target :StitchCoreAWSS3ServiceTests do
        inherit! :search_paths
    end
end

target :StitchCoreAWSService do
    project 'Core/Services/StitchCoreAWSService/StitchCoreAWSService.xcodeproj'

    target :StitchCoreAWSServiceTests do
        inherit! :search_paths
    end
end

target :StitchCore do
  project 'Darwin/StitchCore/StitchCore.xcodeproj'

  target :StitchCoreTests do
      pod 'JSONWebToken', '2.2.0'
  end
end

target :StitchDarwinCoreTestUtils do
    project 'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils.xcodeproj'

    target :StitchDarwinCoreTestUtilsTests do
        inherit! :search_paths
    end
end

target :StitchTwilioService do
    project 'Darwin/Services/StitchTwilioService/StitchTwilioService.xcodeproj'

    target :StitchTwilioServiceTests do
        inherit! :search_paths
    end
end

target :StitchRemoteMongoDBService do
    project 'Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj'

    target :StitchRemoteMongoDBServiceTests do
        inherit! :search_paths
    end
end

target :StitchLocalMongoDBService do
  project 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj'
  pod 'MongoMobile', '~> 0.0.3'

  target :StitchLocalMongoDBServiceTests do
      inherit! :search_paths
  end
end

target :StitchHTTPService do
    project 'Darwin/Services/StitchHTTPService/StitchHTTPService.xcodeproj'

    target :StitchHTTPServiceTests do
        inherit! :search_paths
    end
end

target :StitchFCMService do
    project 'Darwin/Services/StitchFCMService/StitchFCMService.xcodeproj'

    target :StitchFCMServiceTests do
        inherit! :search_paths
    end
end

target :StitchAWSSESService do
    project 'Darwin/Services/StitchAWSSESService/StitchAWSSESService.xcodeproj'

    target :StitchAWSSESServiceTests do
        inherit! :search_paths
    end
end

target :StitchAWSS3Service do
    project 'Darwin/Services/StitchAWSS3Service/StitchAWSS3Service.xcodeproj'

    target :StitchAWSS3ServiceTests do
        inherit! :search_paths
    end
end

target :StitchAWSService do
    project 'Darwin/Services/StitchAWSService/StitchAWSService.xcodeproj'

    target :StitchAWSServiceTests do
        inherit! :search_paths
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        # this is to fix a bug in JSONWebToken
        if target.name == 'JSONWebToken'
            system("rm -rf Pods/JSONWebToken/CommonCrypto")
        end
    end
end
