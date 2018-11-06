workspace 'Stitch.xcworkspace'

platform :ios, '11.0'

target :MockUtils do
    project 'MockUtils/MockUtils.xcodeproj'
end

json_web_token_podspec = 'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/6/1/a/JSONWebToken/2.2.0/JSONWebToken.podspec.json'
swifter_podspec = 'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/4/2/2/Swifter/1.4.5/Swifter.podspec.json'
mongo_swift_podspec = 'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/4/5/d/MongoSwift/0.0.5/MongoSwift.podspec.json'
mongo_mobile_podspec = 'https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/9/5/d/MongoMobile/0.0.3/MongoMobile.podspec.json'

target :StitchCoreSDK do
    pod 'MongoSwift', :podspec => mongo_swift_podspec

    project 'Core/StitchCoreSDK/StitchCoreSDK.xcodeproj'

    target :StitchCoreAdminClient do    
        project 'Core/StitchCoreAdminClient/StitchCoreAdminClient.xcodeproj'

        inherit! :search_paths
    end

    target :StitchCoreSDKMocks do
        inherit! :search_paths
    end

    target :StitchCoreSDKTests do
        pod 'JSONWebToken', :podspec => json_web_token_podspec
        pod 'Swifter', :podspec => swifter_podspec
        pod 'MongoSwift', :podspec => mongo_swift_podspec

        inherit! :search_paths
    end

    target :StitchCoreFCMService do
        project 'Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreFCMServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end

    target :StitchCoreTwilioService do
        project 'Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj'
        inherit! :search_paths
        
        target :StitchCoreTwilioServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end

    target :StitchCoreRemoteMongoDBService do
        project 'Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj'
        inherit! :search_paths
        
        target :StitchCoreRemoteMongoDBServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end

    target :StitchCoreLocalMongoDBService do
        project 'Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj'
        pod 'MongoMobile', :podspec => mongo_mobile_podspec

        target :StitchCoreLocalMongoDBServiceTests do
            pod 'MongoMobile', :podspec => mongo_mobile_podspec
            inherit! :search_paths
        end
    end

    target :StitchCoreHTTPService do
        project 'Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreHTTPServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSSESService do
        project 'Core/Services/StitchCoreAWSSESService/StitchCoreAWSSESService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreAWSSESServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSS3Service do
        project 'Core/Services/StitchCoreAWSS3Service/StitchCoreAWSS3Service.xcodeproj'
        inherit! :search_paths
        
        target :StitchCoreAWSS3ServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end
    
    target :StitchCoreAWSService do
        project 'Core/Services/StitchCoreAWSService/StitchCoreAWSService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreAWSServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
            inherit! :search_paths
        end
    end

    target :StitchCore do
        project 'Darwin/StitchCore/StitchCore.xcodeproj'
        inherit! :search_paths
    
        target :StitchCoreTests do
            pod 'JSONWebToken', :podspec => json_web_token_podspec
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchDarwinCoreTestUtils do
        project 'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils.xcodeproj'
        inherit! :search_paths
    
        target :StitchDarwinCoreTestUtilsTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchTwilioService do
        project 'Darwin/Services/StitchTwilioService/StitchTwilioService.xcodeproj'
        inherit! :search_paths
    
        target :StitchTwilioServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchRemoteMongoDBService do
        project 'Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj'
        inherit! :search_paths
    
        target :StitchRemoteMongoDBServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchLocalMongoDBService do
        project 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj'
        pod 'MongoMobile', :podspec => mongo_mobile_podspec
    
        target :StitchLocalMongoDBServiceTests do
            pod 'MongoMobile', :podspec => mongo_mobile_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchHTTPService do
        project 'Darwin/Services/StitchHTTPService/StitchHTTPService.xcodeproj'
        inherit! :search_paths
    
        target :StitchHTTPServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchFCMService do
        project 'Darwin/Services/StitchFCMService/StitchFCMService.xcodeproj'
        inherit! :search_paths
    
        target :StitchFCMServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchAWSSESService do
        project 'Darwin/Services/StitchAWSSESService/StitchAWSSESService.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSSESServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchAWSS3Service do
        project 'Darwin/Services/StitchAWSS3Service/StitchAWSS3Service.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSS3ServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchAWSService do
        project 'Darwin/Services/StitchAWSService/StitchAWSService.xcodeproj'
        inherit! :search_paths
    
        target :StitchAWSServiceTests do
            pod 'MongoSwift', :podspec => mongo_swift_podspec
    
            inherit! :search_paths
        end
    end
    
    target :StitchCoreTestUtils do
        project 'Core/StitchCoreTestUtils/StitchCoreTestUtils.xcodeproj'
    
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
