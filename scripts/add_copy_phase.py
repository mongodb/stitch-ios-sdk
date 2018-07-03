from pbxproj import XcodeProject
from pbxproj.XcodeProject import FileOptions

import os

modules = [
    'Core/StitchCoreSDK',
    'Core/StitchCoreAdminClient',
    'Core/StitchCoreTestUtils',
    'Core/Services/StitchCoreAWSS3Service',
    'Core/Services/StitchCoreAWSSESService',
    'Core/Services/StitchCoreFCMService',
    'Core/Services/StitchCoreHTTPService',
    'Core/Services/StitchCoreLocalMongoDBService',
    'Core/Services/StitchCoreRemoteMongoDBService',
    'Core/Services/StitchCoreTwilioService',
    'Darwin/StitchCore',
    'Darwin/Services/StitchAWSS3Service',
    'Darwin/Services/StitchAWSSESService',
    'Darwin/Services/StitchFCMService',
    'Darwin/Services/StitchHTTPService',
    'Darwin/Services/StitchLocalMongoDBService',
    'Darwin/Services/StitchRemoteMongoDBService',
    'Darwin/Services/StitchTwilioService',
]


# open the project
for module in modules:
    project = XcodeProject.load('{}/{}.xcodeproj/project.pbxproj'.format(module, os.path.basename(module)))

    frameworks = [
        os.path.abspath('Frameworks/ios/libbson.framework'),
        os.path.abspath('Frameworks/ios/libmongoc.framework'),
        os.path.abspath('Frameworks/ios/MongoSwift.framework')
    ]

    # add a file to it, force=false to not add it if it's already in the project
    options = FileOptions(create_build_files=True, weak=True, embed_framework=True, code_sign_on_copy=True)

    for fmk in frameworks:
        project.add_file(fmk, file_options=options)

    # save the project, otherwise your changes won't be picked up by Xcode
    project.save()