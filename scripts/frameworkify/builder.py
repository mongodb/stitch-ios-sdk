from swift import SwiftSource
from frameworks import SwiftFrameworkModule
from modules import Module

from platforms import platforms
from util import log_error, set_verbosity, change_library_rpath
from glob import glob
from shutil import copytree, rmtree

class FrameworkBuilder:
    def __init__(
        self,
        source_paths,
        sdk,
        target_version,
        output,
        framework_search_paths,
        import_paths,
        excludes = [],
        enable_testing = False,
        xctest = False,
        xctest_bundle = False,
        xcode_path='/Applications/Xcode.app'):
        global FRAMEWORKS_DIR
        FRAMEWORKS_DIR = 'Frameworks'
        global OUTPUT
        OUTPUT = output
        if sdk is None:
            log_error('must have sdk')
            exit(1)
        try:
            tuples = list(map(lambda platform: (platform, platform.variants), platforms))
            variants_to_platforms = dict(t for sublist in map(lambda tup: map(
                lambda variant: (variant.name, tup[0]),
                tup[1]), tuples) for t in sublist)
            
            variants_to_variants = dict(t for sublist in map(lambda tup: map(
                lambda variant: (variant.name, variant),
                tup[1]), tuples) for t in sublist)

            import fnmatch
            import os

            source_matches = []
            headers = []
            for source_path in source_paths:
                print source_path
                for root, dirnames, filenames in os.walk(source_path):
                    for filename in fnmatch.filter(filenames, '*.swift'):
                        source_matches.append(os.path.join(root, filename))
                    for filename in fnmatch.filter(filenames, '*.h'):
                        headers.append(os.path.join(root, filename))

            platform = variants_to_platforms[sdk]
            variant = variants_to_variants[sdk]

            print platform.name
            print variant.name
            excludes = excludes
            for exclusion in excludes:
                if exclusion in source_matches:
                    source_matches.remove(exclusion)

            flags = []
            if import_paths is not None:
                flags += ['-I' + ' -I'.join(import_paths)]

            if len(headers) > 0:
                for header in headers:
                    flags += ['-import-objc-header', header]
            if enable_testing:
                flags += ['-enable-testing', '-emit-loaded-module-trace', '-dump-usr', '-parseable-output']
            
            if xctest:
                flags += [
                    '-F{}/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks'.format(xcode_path),
                    '-Xlinker',
                    '-rpath',
                    '-Xlinker',
                    'Frameworks/macos',
                    '-Xlinker',
                    '-rpath',
                    '-Xlinker',
                    '{}/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks'.format(xcode_path)
                ]

            if xctest_bundle or enable_testing:
                flags += [
                    '-profile-generate',
                    '-profile-coverage-mapping'
                ]
            
            SwiftFrameworkModule(
                SwiftSource(
                    OUTPUT, 
                    source_matches, 
                    framework_search_paths,
                    flags = flags).create_module(
                        platform, 
                        variant,
                        target_version
                    )).create('Frameworks')

            if os.path.exists('Frameworks/{}/{}.{}'.format(platform.name, OUTPUT, 'framework' if xctest_bundle is False else 'xctest')):
                rmtree('Frameworks/{}/{}.{}'.format(platform.name, OUTPUT, 'framework' if xctest_bundle is False else 'xctest'))
            copytree(
                'Frameworks/{}/{}/{}.framework'.format(platform.full_name, variant.name, OUTPUT), 
                'Frameworks/{}/{}.{}'.format(platform.name, OUTPUT, 'framework' if xctest_bundle is False else 'xctest'))
            rmtree('.tmp')
            rmtree('Frameworks/{}'.format(platform.full_name))
        except Exception as e:
            log_error(e)
            try:
                rmtree('.tmp')
                rmtree('Frameworks/{}'.format(platform.full_name))
            except:
                raise e
