from frameworkify import FrameworkBuilder, set_verbosity
from subprocess import call, Popen, PIPE
from collections import OrderedDict
import argparse
import os

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


dependencies = OrderedDict([
    ('Swifter', mini_module('Swifter/Sources',
                            imports='JSONWebToken/CommonCrypto')),
    ('JWA', mini_module('JSONWebToken/Sources/JWA',
                        imports='JSONWebToken/CommonCrypto',
                        excludes='JSONWebToken/Sources/JWA/HMAC/HMACCryptoSwift.swift')),
    ('JWT', mini_module('JSONWebToken/Sources/JWT',
                        imports='JSONWebToken/CommonCrypto')),
    ('MockUtils', mini_module('MockUtils/Sources')),
])

test_utils_source = [
    'Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils',
    'Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils'
]

test_utils = OrderedDict([
    ('StitchCoreTestUtils', mini_module('Core/StitchCoreTestUtils/Sources/StitchCoreTestUtils')),
    ('StitchDarwinCoreTestUtils', mini_module('Darwin/StitchDarwinCoreTestUtils/StitchDarwinCoreTestUtils'))
])

modules = OrderedDict([
    # Core
    ('StitchCoreSDK', mini_module('Core/StitchCoreSDK/Sources/StitchCoreSDK')),
    ('StitchCoreAdminClient', mini_module('Core/StitchCoreAdminClient/Sources/StitchCoreAdminClient')),
    ('StitchCoreSDKMocks', mini_module('Core/StitchCoreSDK/Sources/StitchCoreSDKMocks', imports='JSONWebToken/CommonCrypto')),
    ('StitchCoreAWSService', mini_module('Core/Services/StitchCoreAWSService/Sources/StitchCoreAWSService')),
    ('StitchCoreAWSS3Service', mini_module('Core/Services/StitchCoreAWSS3Service/Sources/StitchCoreAWSS3Service')),
    ('StitchCoreAWSSESService', mini_module('Core/Services/StitchCoreAWSSESService/Sources/StitchCoreAWSSESService')),
    ('StitchCoreFCMService', mini_module('Core/Services/StitchCoreFCMService/Sources/StitchCoreFCMService')),
    ('StitchCoreHTTPService', mini_module('Core/Services/StitchCoreHTTPService/Sources/StitchCoreHTTPService')),
    ## Disabled until embedded frameworks available 
    # 'StitchCoreLocalMongoDBService', 'Core/Services/StitchCoreLocalMongoDBService'),
    ('StitchCoreRemoteMongoDBService', \
        mini_module('Core/Services/StitchCoreRemoteMongoDBService/Sources/StitchCoreRemoteMongoDBService')),
    ('StitchCoreTwilioService', \
        mini_module('Core/Services/StitchCoreTwilioService/Sources/StitchCoreTwilioService')),
    # Darwin
    ('StitchCore', mini_module('Darwin/StitchCore/StitchCore')),
    ('StitchAWSService', mini_module('Darwin/Services/StitchAWSService/StitchAWSService')),
    ('StitchAWSS3Service', mini_module('Darwin/Services/StitchAWSS3Service/StitchAWSS3Service')),
    ('StitchAWSSESService', mini_module('Darwin/Services/StitchAWSSESService/StitchAWSSESService')),
    ('StitchFCMService', mini_module('Darwin/Services/StitchFCMService/StitchFCMService')),
    ('StitchHTTPService', mini_module('Darwin/Services/StitchHTTPService/StitchHTTPService')),
    ## Disabled until embedded frameworks available 
    # 'StitchLocalMongoDBService', 'Darwin/Services/StitchLocalMongoDBService'),
    ('StitchRemoteMongoDBService', mini_module('Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBService')),
    ('StitchTwilioService', mini_module('Darwin/Services/StitchTwilioService/StitchTwilioService'))
])

core_tests = OrderedDict([
    # Core
    ('StitchCoreSDKTests', mini_module('Core/StitchCoreSDK/Tests/StitchCoreSDKTests', imports='JSONWebToken/CommonCrypto')),
    ('StitchCoreAWSServiceTests', mini_module('Core/Services/StitchCoreAWSService/Tests/StitchCoreAWSServiceTests')),
    ('StitchCoreAWSS3ServiceTests', mini_module('Core/Services/StitchCoreAWSS3Service/Tests/StitchCoreAWSS3ServiceTests')),
    ('StitchCoreAWSSESServiceTests', mini_module('Core/Services/StitchCoreAWSSESService/Tests/StitchCoreAWSSESServiceTests')),
    ('StitchCoreFCMServiceTests', mini_module('Core/Services/StitchCoreFCMService/Tests/StitchCoreFCMServiceTests')),
    ('StitchCoreHTTPServiceTests', mini_module('Core/Services/StitchCoreHTTPService/Tests/StitchCoreHTTPServiceTests')),
    ## Disabled until embedded frameworks available 
    # 'StitchCoreLocalMongoDBServiceTests', 'Core/Services/StitchCoreLocalMongoDBService/Tests/StitchCoreLocalMongoDBService'),
    ('StitchCoreRemoteMongoDBServiceTests', mini_module('Core/Services/StitchCoreRemoteMongoDBService/Tests/StitchCoreRemoteMongoDBServiceTests')),
    ('StitchCoreTwilioServiceTests', mini_module('Core/Services/StitchCoreTwilioService/Tests/StitchCoreTwilioServiceTests')),
])

darwin_tests = OrderedDict([
    # Darwin
    ('StitchCoreTests', mini_module('Darwin/StitchCore/StitchCoreTests', imports='JSONWebToken/CommonCrypto')),
    ('StitchAWSServiceTests', \
        mini_module('Darwin/Services/StitchAWSService/StitchAWSServiceTests', imports='JSONWebToken/CommonCrypto')),
    ('StitchAWSS3ServiceTests', mini_module('Darwin/Services/StitchAWSS3Service/StitchAWSS3ServiceTests')),
    ('StitchAWSSESServiceTests', \
        mini_module('Darwin/Services/StitchAWSSESService/StitchAWSSESServiceTests', imports='JSONWebToken/CommonCrypto')),
    ('StitchFCMServiceTests', mini_module('Darwin/Services/StitchFCMService/StitchFCMServiceTests')),
    ('StitchHTTPServiceTests', mini_module('Darwin/Services/StitchHTTPService/StitchHTTPServiceTests')),
    ## Disabled until embedded frameworks available 
    # 'StitchLocalMongoDBService', 'Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBServiceTests',
    ('StitchRemoteMongoDBServiceTests', mini_module('Darwin/Services/StitchRemoteMongoDBService/StitchRemoteMongoDBServiceTests')),
    ('StitchTwilioServiceTests', mini_module('Darwin/Services/StitchTwilioService/StitchTwilioServiceTests'))
])

set_verbosity(True)

SDKS = [
    'macosx', 
    'iphoneos']
TARGET_VERSIONS = [
    '10.10', 
    '10.2']
FRAMEWORK_SEARCH_PATH_PATHS = [
    'Frameworks/macos', 
    'Frameworks/ios']

parser = argparse.ArgumentParser()
parser.add_argument('-xcode-path', 
                    '--xcode-path',
                    default='/Applications/Xcode.app')
parser.add_argument('-t',
                    '--test',
                    default=True)
args = parser.parse_args()

test = args.test

if test is True:
    SDKS.remove('iphoneos')

for i in range(0, len(SDKS)):
    SDK = SDKS[i]
    TARGET_VERSION = TARGET_VERSIONS[i]
    FRAMEWORK_SEARCH_PATHS = FRAMEWORK_SEARCH_PATH_PATHS[i]
    enable_testing = test
    for module, mini_module in dependencies.iteritems():
        FrameworkBuilder(
            mini_module.source_paths, 
            SDK, 
            TARGET_VERSION, 
            module, 
            FRAMEWORK_SEARCH_PATHS, 
            import_paths=mini_module.import_paths,
            excludes = mini_module.excludes,
            enable_testing = enable_testing,
            xctest = False,
            xcode_path=args.xcode_path)

    for module, mini_module in modules.iteritems():
        FrameworkBuilder(
            mini_module.source_paths, 
            SDK, 
            TARGET_VERSION, 
            module, 
            FRAMEWORK_SEARCH_PATHS, 
            import_paths=mini_module.import_paths,
            excludes = mini_module.excludes,
            enable_testing = enable_testing,
            xctest = False,
            xcode_path=args.xcode_path)
        prof_data_file = '{}.profdata'.format(module)
        call([
            'xcrun', 
            'llvm-profdata',
            'merge',
            '-o',
            prof_data_file,
            'default.profraw'
        ])

    for module, mini_module in test_utils.iteritems():
        FrameworkBuilder(
            mini_module.source_paths, 
            SDK, 
            TARGET_VERSION, 
            module, 
            FRAMEWORK_SEARCH_PATHS, 
            import_paths=mini_module.import_paths,
            excludes = mini_module.excludes,
            enable_testing = False,
            xctest = True,
            xcode_path=args.xcode_path)

    if os.path.exists('CoverageData') is False:
        os.mkdir('CoverageData')

    if test is True:
        for module, mini_module in core_tests.iteritems():
            FrameworkBuilder(
                mini_module.source_paths, 
                SDK, 
                TARGET_VERSION, 
                module, 
                FRAMEWORK_SEARCH_PATHS, 
                import_paths=mini_module.import_paths,
                excludes = mini_module.excludes,
                enable_testing = False,
                xctest = True,
                xctest_bundle=True,
                xcode_path=args.xcode_path)
            run_xctest(module)
            module_name = module.split('Tests')[0]
            prof_data_file = '{}.profdata'.format(module_name)
            call([
                'xcrun', 
                'llvm-profdata',
                'merge',
                '-o',
                prof_data_file,
                'default.profraw',
                prof_data_file
            ])
            coverage_data = Popen([
                'xcrun', 
                'llvm-cov', 
                'show', 
                '-instr-profile={}'.format(prof_data_file),
                'Frameworks/macos/{}.framework/{}'.format(module_name, module_name)
            ], stdout=PIPE).stdout.read()
            open('CoverageData/{}.cov'.format(module_name), 'w').write(coverage_data)

        for module, mini_module in darwin_tests.iteritems():
            FrameworkBuilder(
                mini_module.source_paths + test_utils_source, 
                SDK, 
                TARGET_VERSION, 
                module, 
                FRAMEWORK_SEARCH_PATHS, 
                import_paths=mini_module.import_paths,
                excludes = mini_module.excludes,
                enable_testing = False,
                xctest = True,
                xctest_bundle=True,
                xcode_path=args.xcode_path)
            run_xctest(module)
