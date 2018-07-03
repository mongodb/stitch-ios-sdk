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
    'Core/Services/StitchCoreTwilioService'
]

test = modules[0]

# open the project
project = XcodeProject.load('{}/{}.xcodeproj/project.pbxproj'.format(test, os.path.basename(test)))

# add a file to it, force=false to not add it if it's already in the project
options = FileOptions(create_build_files=True, weak=True, embed_framework=True, code_sign_on_copy=True)
project.add_file('../../Frameworks/ios/libbson.framework', file_options=options)
project.add_file('../../Frameworks/ios/MongoSwift.framework', file_options=options)
project.add_file('../../Frameworks/ios/libmongoc.framework', file_options=options)
# save the project, otherwise your changes won't be picked up by Xcode
project.save()