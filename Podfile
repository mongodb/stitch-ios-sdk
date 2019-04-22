workspace 'Stitch.xcworkspace'

platform :ios, '11.0'
use_frameworks!

pod 'SwiftLint'

target :MockUtils do
    project 'MockUtils/MockUtils.xcodeproj'
end

def shared_pods
    pod 'MongoSwift', '= 0.1.0'
end

def mongo_mobile
    pod 'MongoMobile', :git => 'https://github.com/mongodb/swift-mongo-mobile/', :branch => 'master'
end

def swifter_pod
    pod 'Swifter', '~> 1.4.5'
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
        swifter_pod

        shared_pods
        inherit! :search_paths
    end

    target :StitchCoreFCMService do
        project 'Core/Services/StitchCoreFCMService/StitchCoreFCMService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreFCMServiceTests do
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchCoreTwilioService do
        project 'Core/Services/StitchCoreTwilioService/StitchCoreTwilioService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreTwilioServiceTests do
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchCoreRemoteMongoDBService do
        project 'Core/Services/StitchCoreRemoteMongoDBService/StitchCoreRemoteMongoDBService.xcodeproj'
        mongo_mobile

        inherit! :search_paths
        target :StitchCoreRemoteMongoDBServiceTests do
            mongo_mobile
            inherit! :search_paths
        end
    end

    target :StitchCoreLocalMongoDBService do
        project 'Core/Services/StitchCoreLocalMongoDBService/StitchCoreLocalMongoDBService.xcodeproj'
        mongo_mobile

        inherit! :search_paths
        target :StitchCoreLocalMongoDBServiceTests do
            shared_pods
            mongo_mobile
            inherit! :search_paths
        end
    end

    target :StitchCoreHTTPService do
        project 'Core/Services/StitchCoreHTTPService/StitchCoreHTTPService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreHTTPServiceTests do
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchCoreAWSService do
        project 'Core/Services/StitchCoreAWSService/StitchCoreAWSService.xcodeproj'
        inherit! :search_paths

        target :StitchCoreAWSServiceTests do
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchCore do
        project 'Darwin/StitchCore/StitchCore.xcodeproj'
        inherit! :search_paths

        target :StitchCoreTests do
            pod 'JSONWebToken', '~> 2.2.0'
            swifter_pod
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchDarwinCoreTestUtils do
        project 'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils.xcodeproj'
        inherit! :search_paths

        target :StitchDarwinCoreTestUtilsTests do
            shared_pods
            inherit! :search_paths
        end
    end

    target :StitchTwilioService do
        project 'Darwin/Services/StitchTwilioService/StitchTwilioService.xcodeproj'
        inherit! :search_paths

        target :StitchTwilioServiceTests do
            shared_pods
            swifter_pod
            inherit! :search_paths
        end
    end

    target :StitchRemoteMongoDBService do
        project 'Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService.xcodeproj'
        inherit! :search_paths

        target :StitchRemoteMongoDBServiceTests do
            swifter_pod
            mongo_mobile
            
            inherit! :search_paths
        end
        
        target :StitchSyncPerformanceTests do
            swifter_pod
            mongo_mobile
            
            inherit! :search_paths
        end
    end

    target :StitchLocalMongoDBService do
        project 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService.xcodeproj'
        mongo_mobile

        target :StitchLocalMongoDBServiceTests do
            mongo_mobile
            swifter_pod
            inherit! :search_paths
        end
    end

    target :StitchHTTPService do
        project 'Darwin/Services/StitchHTTPService/StitchHTTPService.xcodeproj'
        inherit! :search_paths

        target :StitchHTTPServiceTests do
            shared_pods
            swifter_pod
            inherit! :search_paths
        end
    end

    target :StitchFCMService do
        project 'Darwin/Services/StitchFCMService/StitchFCMService.xcodeproj'
        inherit! :search_paths

        target :StitchFCMServiceTests do
            shared_pods
            swifter_pod
            inherit! :search_paths
        end
    end

    target :StitchAWSService do
        project 'Darwin/Services/StitchAWSService/StitchAWSService.xcodeproj'
        inherit! :search_paths

        target :StitchAWSServiceTests do
            shared_pods
            swifter_pod
            inherit! :search_paths
        end
    end

    target :StitchCoreTestUtils do
        project 'Core/StitchCoreTestUtils/StitchCoreTestUtils.xcodeproj'
        swifter_pod

        shared_pods
        inherit! :search_paths
    end
end

target :ToDoSync do
    project 'Darwin/Examples/ToDoSync/ToDoSync.xcodeproj'
    mongo_mobile
    pod 'Toast-Swift', '= 4.0.0'
    pod 'BEMCheckBox', '= 1.4.1'
end

target :StitchSDK do
    pod 'MongoSwift', '= 0.1.0'

    project 'Darwin/StitchSDK/StitchSDK.xcodeproj'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        # this is to fix an issue that happens between cocoapods and xcode 10
        target.build_configurations.each do |config|
            config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
        end

        # this is to fix a bug in JSONWebToken
        if target.name == 'JSONWebToken'
            system("rm -rf Pods/JSONWebToken/CommonCrypto")
        end
    end
end
