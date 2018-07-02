import os
from subprocess import call
from frameworkify import platforms

modules = [
    'MockUtils',
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

frameworks_dir = os.path.abspath('./Frameworks')

tuples = list(map(lambda platform: (platform.name, platform.variants), platforms))

xcconfig = '\n'.join([line for sub_list in map(lambda tup: map(
    lambda variant: "FRAMEWORK_SEARCH_PATHS[sdk={}*]={}/{}\nLD_RUNPATH_SEARCH_PATHS[sdk={}*]={}/{}".format(
        variant.name, frameworks_dir, tup[0], variant.name, frameworks_dir, tup[0]),
        tup[1]),
    tuples) for line in sub_list] + [
        'ENABLE_BITCODE=NO',
        'IPHONEOS_DEPLOYMENT_TARGET=10.2'
    ])

og_path = os.path.abspath('.')

for module in modules:
    os.chdir(module)

    open('{}.xcconfig'.format(os.path.basename(module)), 'w+').write(
        xcconfig)

    os.chdir(og_path)
