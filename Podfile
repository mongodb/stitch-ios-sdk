workspace 'Stitch.xcworkspace'

platform :ios, '11.0'

target :StitchCoreAdminClient do
  project 'Core/StitchCoreAdminClient/StitchCoreAdminClient.xcodeproj'
end

target :StitchCoreTestUtils do
    project 'Core/StitchCoreTestUtils/StitchCoreTestUtils.xcodeproj'
end

target :MockUtils do
    project 'MockUtils/MockUtils.xcodeproj'
end

pod 'MongoSwift', '~> 0.0.5'

target 'StitchCoreSDK' do
    project 'Core/StitchCoreSDK/StitchCoreSDK.xcodeproj'

    target :StitchCoreSDKMocks do
        inherit! :search_paths
    end

    target 'StitchCoreSDKTests' do
        pod 'JSONWebToken', '2.2.0'
        pod 'Swifter', '1.4.5'
    end
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

target :StitchCore do
  project 'Darwin/StitchCore/StitchCore.xcodeproj'

  target :StitchCoreTests do
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

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'JSONWebToken'
            system("rm -rf Pods/JSONWebToken/CommonCrypto")
        end
    end
end
