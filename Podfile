workspace 'Stitch.xcworkspace'

platform :ios, '11.0'
use_frameworks!

pod 'SwiftLint'

target :MockUtils do
    project 'MockUtils/MockUtils.xcodeproj'
end

def shared_pods
    pod 'MongoSwift', '= 0.0.7'
end

target :StitchCoreSDK do
    shared_pods
    project 'Core/StitchCoreSDK/StitchCoreSDK.xcodeproj'

    target :StitchCoreAdminClient do    
        project 'Core/StitchCoreAdminClient/StitchCoreAdminClient.xcodeproj'
        inherit! :search_paths
    end

    target :StitchCoreSDKMocks do
        inherit! :search_paths
    end

    target :StitchCoreSDKTests do
        pod 'JSONWebToken', '~> 2.2.0'
        pod 'Swifter', '~> 1.4.5'

        inherit! :search_paths
    end

    target :StitchCoreFCMService do
        project 'Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreFCMServiceTests do
            inherit! :search_paths
        end
    end

    target :StitchCoreTwilioService do
        project 'Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj'
        inherit! :search_paths
        
        target :StitchCoreTwilioServiceTests do
            inherit! :search_paths
        end
    end

    target :StitchCoreRemoteMongoDBService do
        project 'Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj'
        pod 'MongoMobile', '= 0.0.5'

        inherit! :search_paths
        target :StitchCoreRemoteMongoDBServiceTests do
            pod 'MongoMobile', '= 0.0.5'
            inherit! :search_paths
        end
    end

    target :StitchCoreLocalMongoDBService do
        project 'Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj'
        pod 'MongoMobile', '= 0.0.5'

        inherit! :search_paths
        target :StitchCoreLocalMongoDBServiceTests do
            inherit! :search_paths
        end
    end

    target :StitchCoreHTTPService do
        project 'Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreHTTPServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSSESService do
        project 'Core/Services/StitchCoreAWSSESService/StitchCoreAWSSESService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreAWSSESServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSS3Service do
        project 'Core/Services/StitchCoreAWSS3Service/StitchCoreAWSS3Service.xcodeproj'
        inherit! :search_paths
        
        target :StitchCoreAWSS3ServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSService do
        project 'Core/Services/StitchCoreAWSService/StitchCoreAWSService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreAWSServiceTests do
            inherit! :search_paths
        end
    end

    target :StitchCore do
        project 'Darwin/StitchCore/StitchCore.xcodeproj'
        inherit! :search_paths
    
        target :StitchCoreTests do
            pod 'JSONWebToken', '~> 2.2.0'
            inherit! :search_paths
        end
    end
    
    target :StitchDarwinCoreTestUtils do
        project 'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils.xcodeproj'
        inherit! :search_paths
    
        target :StitchDarwinCoreTestUtilsTests do
            inherit! :search_paths
        end
    end
    
    target :StitchTwilioService do
        project 'Darwin/Services/StitchTwilioService/StitchTwilioService.xcodeproj'
        inherit! :search_paths
    
        target :StitchTwilioServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchRemoteMongoDBService do
        project 'Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj'
        inherit! :search_paths
    
        target :StitchRemoteMongoDBServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchLocalMongoDBService do
        project 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj'
        pod 'MongoMobile', '= 0.0.5'
    
        target :StitchLocalMongoDBServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchHTTPService do
        project 'Darwin/Services/StitchHTTPService/StitchHTTPService.xcodeproj'
        inherit! :search_paths
    
        target :StitchHTTPServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchFCMService do
        project 'Darwin/Services/StitchFCMService/StitchFCMService.xcodeproj'
        inherit! :search_paths
    
        target :StitchFCMServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchAWSSESService do
        project 'Darwin/Services/StitchAWSSESService/StitchAWSSESService.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSSESServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchAWSS3Service do
        project 'Darwin/Services/StitchAWSS3Service/StitchAWSS3Service.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSS3ServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchAWSService do
        project 'Darwin/Services/StitchAWSService/StitchAWSService.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSServiceTests do
            inherit! :search_paths
        end
    end
    
    target :StitchCoreTestUtils do
        project 'Core/StitchCoreTestUtils/StitchCoreTestUtils.xcodeproj'
        inherit! :search_paths
    end    
end

target :StitchSDK do
    pod 'MongoSwift', '= 0.0.7'

    project 'Darwin/StitchSDK/StitchSDK.xcodeproj'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        # this is to fix a bug in JSONWebToken
        if target.name == 'JSONWebToken'
            system("rm -rf Pods/JSONWebToken/CommonCrypto")
        end
    end
end