from frameworkify import FrameworkBuilder, set_verbosity
from subprocess import call
from collections import OrderedDict

class mini_module:
    def __init__(self, source_paths, excludes = None, imports = None):
        self.source_paths = [source_paths]
        self.excludes = [excludes]
        self.import_paths = [imports] if imports is not None else None

def run_xctest(fmk_name):
    exit_code = call(['xcrun', 'xctest', 'Frameworks/macos/{}.xctest'.format(fmk_name)])
    if exit_code is not 0:
        print 'Test(s) Failed for {}'.format(fmk_name)
        exit(exit_code)


dependencies = OrderedDict({
    'Swifter': mini_module('Swifter/Sources',
                            imports='CommonCrypto'),
    'JWA': mini_module('JSONWebToken/Sources/JWA',
                        imports='CommonCrypto',
                        excludes='JSONWebToken/Sources/JWA/HMAC/HMACCryptoSwift.swift'),
    'JWT': mini_module('JSONWebToken/Sources/JWT',
                        imports='CommonCrypto'),
    'MockUtils': mini_module('MockUtils/Sources'),
}.items())

test_utils = [
    'Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils',
    'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils'
]

modules = OrderedDict({
    # Core
    'StitchCoreSDK': mini_module('Core/StitchCoreSDK/Sources/StitchCoreSDK'),
    'StitchCoreAdminClient': mini_module('Core/StitchCoreAdminClient/Sources/StitchCoreAdminClient'),
    'StitchCoreSDKMocks': mini_module('Core/StitchCoreSDK/Sources/StitchCoreSDKMocks', imports='CommonCrypto'),
    'StitchCoreAWSS3Service': mini_module('Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service'),
    'StitchCoreAWSSESService': mini_module('Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService'),
    'StitchCoreFCMService': mini_module('Core/Services/StitchCoreFCMService/Sources/StitchCoreFCMService'),
    'StitchCoreHTTPService': mini_module('Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService'),
    ## Disabled until embedded frameworks available 
    # 'StitchCoreLocalMongoDBService': 'Core/Services/StitchCoreLocalMongoDBService',
    'StitchCoreRemoteMongoDBService': \
        mini_module('Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService'),
    'StitchCoreTwilioService': \
        mini_module('Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService'),
    # Darwin
    'StitchCore': mini_module('Darwin/StitchCore/StitchCore'),
    'StitchAWSS3Service': mini_module('Darwin/Services/StitchAWSS3Service/StitchAWSS3Service'),
    'StitchAWSSESService': mini_module('Darwin/Services/StitchAWSSESService/StitchAWSSESService'),
    'StitchFCMService': mini_module('Darwin/Services/StitchFCMService/StitchFCMService'),
    'StitchHTTPService': mini_module('Darwin/Services/StitchHTTPService/StitchHTTPService'),
    ## Disabled until embedded frameworks available 
    # 'StitchLocalMongoDBService': 'Darwin/Services/StitchLocalMongoDBService',
    'StitchRemoteMongoDBService': mini_module('Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService'),
    'StitchTwilioService': mini_module('Darwin/Services/StitchTwilioService/StitchTwilioService'),
}.items())

core_tests = OrderedDict({
    # Core
    'StitchCoreSDKTests': mini_module('Core/StitchCoreSDK/Tests/StitchCoreSDKTests', imports='CommonCrypto'),
    'StitchCoreTestUtilsTests': mini_module('Core/StitchCoreTestUtils/Tests/StitchCoreTestUtilsTests'),
    'StitchCoreAWSS3ServiceTests': mini_module('Core/Services/StitchCoreAWSS3Service/Tests/StitchCoreAWSS3ServiceTests'),
    'StitchCoreAWSSESServiceTests': mini_module('Core/Services/StitchCoreAWSSESService/Tests/StitchCoreAWSSESServiceTests'),
    'StitchCoreFCMServiceTests': mini_module('Core/Services/StitchCoreFCMService/Tests/StitchCoreFCMServiceTests'),
    'StitchCoreHTTPServiceTests': mini_module('Core/Services/StitchCoreHTTPService/Tests/StitchCoreHTTPServiceTests'),
    ## Disabled until embedded frameworks available 
    # 'StitchCoreLocalMongoDBServiceTests': 'Core/Services/StitchCoreLocalMongoDBService/Tests/StitchCoreLocalMongoDBService',
    'StitchCoreRemoteMongoDBServiceTests': mini_module('Core/Services/StitchCoreRemoteMongoDBService/Tests/StitchCoreRemoteMongoDBServiceTests'),
    'StitchCoreTwilioServiceTests': mini_module('Core/Services/StitchCoreTwilioService/Tests/StitchCoreTwilioServiceTests'),
}.items())

darwin_tests = OrderedDict({
    # Darwin
    'StitchCoreTests': mini_module('Darwin/StitchCore/StitchCoreTests'),
    'StitchAWSS3ServiceTests': mini_module('Darwin/Services/StitchAWSS3Service/StitchAWSS3ServiceTests'),
    'StitchAWSSESServiceTests': mini_module('Darwin/Services/StitchAWSSESService/StitchAWSSESServiceTests', imports='CommonCrypto'),
    'StitchFCMServiceTests': mini_module('Darwin/Services/StitchFCMService/StitchFCMServiceTests'),
    'StitchHTTPServiceTests': mini_module('Darwin/Services/StitchHTTPService/StitchHTTPServiceTests'),
    ## Disabled until embedded frameworks available 
    # 'StitchLocalMongoDBService': 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBServiceTests',
    'StitchRemoteMongoDBServiceTests': mini_module('Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBServiceTests'),
    'StitchTwilioServiceTests': mini_module('Darwin/Services/StitchTwilioService/StitchTwilioServiceTests')
}.items())

set_verbosity(True)

# for module, mini_module in dependencies.iteritems():
#     FrameworkBuilder(
#         mini_module.source_paths, 
#         'macosx', 
#         '10.10', 
#         module, 
#         'Frameworks/macos', 
#         import_paths=mini_module.import_paths,
#         excludes = mini_module.excludes,
#         enable_testing = True,
#         xctest = False)

# for module, mini_module in modules.iteritems():
#     FrameworkBuilder(
#         mini_module.source_paths, 
#         'macosx', 
#         '10.10', 
#         module, 
#         'Frameworks/macos', 
#         import_paths=mini_module.import_paths,
#         excludes = mini_module.excludes,
#         enable_testing = True,
#         xctest = False)

for module, mini_module in core_tests.iteritems():
    FrameworkBuilder(
        mini_module.source_paths, 
        'macosx', 
        '10.10', 
        module, 
        'Frameworks/macos', 
        import_paths=mini_module.import_paths,
        excludes = mini_module.excludes,
        enable_testing = False,
        xctest = True)
    run_xctest(module)

for module, mini_module in darwin_tests.iteritems():
    FrameworkBuilder(
        mini_module.source_paths + test_utils, 
        'macosx', 
        '10.10', 
        module, 
        'Frameworks/macos', 
        import_paths=mini_module.import_paths,
        excludes = mini_module.excludes,
        enable_testing = False,
        xctest = True)
    run_xctest(module)