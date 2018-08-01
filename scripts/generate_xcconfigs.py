import os
from subprocess import call
from frameworkify import platforms

modules = [
    # core
    'MockUtils',
    'Core/StitchCoreSDK',
    'Core/StitchCoreAdminClient',
    'Core/StitchCoreTestUtils',
    'Core/Services/StitchCoreAWSService',
    'Core/Services/StitchCoreAWSS3Service',
    'Core/Services/StitchCoreAWSSESService',
    'Core/Services/StitchCoreFCMService',
    'Core/Services/StitchCoreHTTPService',
    'Core/Services/StitchCoreLocalMongoDBService',
    'Core/Services/StitchCoreRemoteMongoDBService',
    'Core/Services/StitchCoreTwilioService',
]

# docgen
doc_gen = [
    'kitten.coreservice',
    'kitten.ioscore',
    'kitten.ioscoreservice',
    'kitten'
]

frameworks_dir = os.path.abspath('./Frameworks')

tuples = list(map(lambda platform: (platform.name, platform.variants), platforms))

xcconfig = '\n'.join([line for sub_list in map(lambda tup: map(
    lambda variant: """
    FRAMEWORK_SEARCH_PATHS[sdk={}*]={}/{}
    OTHER_LD_FLAGS[sdk={}*]=-rpath {}/{}""".format(
        variant.name, frameworks_dir, tup[0], variant.name, frameworks_dir, tup[0]),
        tup[1]),
    tuples) for line in sub_list] + [
        'ENABLE_BITCODE=NO',
        'IPHONEOS_DEPLOYMENT_TARGET=10.2',
        'VALID_ARCHS=i386 x86_64 arm64 armv7k armv7 armv7s',
    ])

for module in modules:
    open('{}/{}.xcconfig'.format(module, os.path.basename(module)), 'w').write(
        xcconfig)

if os.path.exists('DocGen/Configs') is False:
    os.mkdir('DocGen/Configs')

for doc in doc_gen:
    open('DocGen/Configs/{}.xcconfig'.format(doc), 'w').write(
        xcconfig
    )
