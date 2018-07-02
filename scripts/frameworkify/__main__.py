from swift import SwiftSource
from frameworks import SwiftFrameworkModule
from modules import Module

from platforms import platforms
import argparse
from util import log_error, set_verbosity, change_library_rpath
from glob import glob
from shutil import copytree, rmtree

parser = argparse.ArgumentParser()
parser.add_argument('source_path',
                    type=str,
                    help="swift source files",
                    nargs='?',
                    metavar='N')
parser.add_argument('-F',
                    '--framework-search-paths',
                    help="""
                    A list of paths to folders containing frameworks
                    to be searched by the compiler for both included or
                    imported header files when compiling C, Objective-C,
                    C++, or Objective-C++, and by the linker for frameworks
                    used by the product.""")
parser.add_argument('-I',
                    '--import-paths',
                    nargs='+',
                    help="""
                    A list of paths to be searched by the Swift compiler
                    for additional Swift modules.""")
parser.add_argument('-excludes',
                    '--excludes',
                    default = [],
                    nargs='+',
                    help="""
                    A list of files to be excluded from the source paths.
                    """)
parser.add_argument('-enable-testing',
                    '--enable-testing',
                    action='store_true',
                    default = False)
parser.add_argument('-xct', 
                    '--xctest', 
                    action='store_true',
                    default=False)
parser.add_argument('-sdk', 
                    '--sdk')
parser.add_argument('-target', 
                    '--target-version')
parser.add_argument('-o', 
                    '--output',
                    default='Frameworks')
parser.add_argument('-v',
                    '--verbose',
                    action='store_true',
                    help='verbose logging')
args = parser.parse_args()

set_verbosity(args.verbose)
FRAMEWORKS_DIR = 'Frameworks'
OUTPUT = args.output

if __name__ == '__main__':
    if args.sdk is None:
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

        framework_search_paths = args.framework_search_paths
        source_path = args.source_path
        import fnmatch
        import os

        matches = []
        for root, dirnames, filenames in os.walk(source_path):
            for filename in fnmatch.filter(filenames, '*.swift'):
                matches.append(os.path.join(root, filename))

        xctest = args.xctest
        platform = variants_to_platforms[args.sdk]
        variant = variants_to_variants[args.sdk]

        excludes = args.excludes
        for exclusion in excludes:
            if exclusion in matches:
                matches.remove(exclusion)

        flags = []
        if args.import_paths is not None:
            flags += ['-I' + ' -I'.join(args.import_paths)]

        if args.enable_testing:
            flags += ['-enable-testing']
        
        if xctest:
            flags += [
                '-F/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks',
                '-Xlinker',
                '-rpath',
                '-Xlinker',
                'Frameworks/macos',
                '-Xlinker',
                '-rpath',
                '-Xlinker',
                '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks'
            ]

        SwiftFrameworkModule(
            SwiftSource(
                OUTPUT, 
                matches, 
                framework_search_paths,
                flags = flags).create_module(
                    platform, 
                    variant,
                    args.target_version
                )).create('Frameworks')

        copytree(
            'Frameworks/{}/{}/{}.framework'.format(platform.full_name, variant.name, OUTPUT), 
            'Frameworks/{}/{}.{}'.format(platform.name, OUTPUT, 'framework' if args.xctest is False else 'xctest'))
        rmtree('.tmp')
        rmtree('Frameworks/{}'.format(platform.full_name))
    except Exception as e:
        log_error(e)
        try:
            rmtree('.tmp')
            rmtree('Frameworks/{}'.format(platform.full_name))
        except:
            raise e
