"""
Download embedded mongo SDKs and covert
the dylibs into .frameworks.
"""
import argparse
import os
import re
import sys
import tarfile
import urllib2

from glob import glob
from multiprocessing import Process, Queue
from shutil import copy2, copyfile, copytree, rmtree
from subprocess import Popen, PIPE, call

def log_error(msg):
    """Log an error to the terminal.

    Arguments:
        msg: str: message to be logged
    """
    print u'\u001b[31merror: {}\u001b[0m'.format(msg)

def log_warning(msg):
    """Log a warning to the terminal.

    Arguments:
        msg: str: message to be logged
    """
    print u'\u001b[93mwarning: {}\u001b[0m'.format(msg)

def log_info(msg):
    """Log info to the terminal.

    Arguments:
        msg: str: message to be logged
    """
    if verbose:
        print u'\u001b[94minfo: {}\u001b[0m'.format(msg)

def change_dylib_identification_name(id, dylib_path):
    """Change the identification name of a given dylib.

    Use the `install_name_tool` command to change the
    identification name of a given dylib.

    Arguments:
        id: str: id to change to
        dylib_path: str: path to the dylib
    """
    if call(['install_name_tool', '-id', id, dylib_path]) is not 0:
        log_error('could not change id of dylib: {}'.format(dylib_path))

def change_dylib_rpath(old_rpath, new_rpath, dylib_path):
    """Change an rpath name of a given dylib.

    Use the `install_name_tool` command to change an
    rpath of a given dylib.

    Arguments:
        old_rpath: str: rpath to change
        new_rpath: str: rpath to change to
        dylib_path: str: path to the dylib
    """
    if call(['install_name_tool', '-change', old_rpath, new_rpath, dylib_path]) is not 0:
        log_error('could not change rpath of dylib: {}'.format(dylib_path))

def lipo(platform, fmks):
    """Lipo frameworks that share the same sdk/arch

    Create a framework that combines the variants
    of a given platform.

    Arguments:
        platform: Platform: ~Platform to build for
        fmks: [Framework]: list of frameworks to lipo
    """
    if len(fmks) is 0:
        return log_error('cannot lipo: no frameworks created')

    cmd = ['lipo', '-create'] + map(lambda fmk: '{}/{}'.format(fmk.abs_path, fmk.name), fmks)
    # output everything to the initial fmk. this is
    # arbitrary. we are going to move everything to
    # the top level anyway
    cmd += ['-o', '{}/{}'.format(fmks[0].abs_path, fmks[0].name)]

    # call the lipo command
    call(cmd)

    # copy them to the new top level
    copytree(
        fmks[0].abs_path,
        'Frameworks/{}/{}.framework'.format(platform.name, fmks[0].framework_name))

class Platform:
    """A supported Apple platform.

    See ~Platforms.

    Arguments:
        name: str: name of this platform
        min_version: int: minimum version supported
    """
    class Variant:
        """A supported variant of a given platform.

        Platforms come in different flavors. Our general
        cases are 'os' and 'simulator'.

        Arguments:
            name: str: name of this variant
            min_version: int: minimum version supported
        """
        def __init__(self, name, min_version):
            self.name = name
            self.min_version = min_version
        
        @property
        def url(self):
            """The url to download the embedded SDK for this variant."""
            return (
            'https://s3.amazonaws.com/mciuploads/mongodb-mongo-master'
            '/embedded-sdk/embedded-sdk-{}-{}'
            '/0dd1fc7ddde2a489558f5328dce5125bddfb9e4d'
            '/mongodb_mongo_master_embedded_sdk_{}_{}'
            '_0dd1fc7ddde2a489558f5328dce5125bddfb9e4d_18_06_11_10_58_10.tgz'.format(
                self.name,
                self.min_version,
                self.name,
                self.min_version))

    def __init__(self, name, full_name, min_version):
        self.name = name
        self.full_name = full_name
        self.min_version = min_version
        # generate os and simulator variants
        self.variants = [
            Platform.Variant(
                name='{}os'.format(full_name), min_version=min_version),
            Platform.Variant(
                name='{}simulator'.format(full_name), min_version=min_version)]

class Platforms:
    """Enumeration of available platforms"""
    iphone = Platform(name='iOS', full_name='iphone', min_version=10.2)
    appletv = Platform(name='tvOS', full_name='appletv', min_version=10.2)
    macosx = Platform(name='osx', full_name='macosx', min_version=10.10)

    # list of each platform
    platforms = [iphone, appletv, macosx]

class Framework(object):
    """A Framework that encapsulates our embedded SDKs.

    See 
    https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/WhatAreFrameworks.html
    for more information.

    Arguments:
        dylib_path: str: the path to the dylib to Framework-ify
        platform: Platform: ~Platform to build this for
    """
    def __init__(self, dylib_path):
        # get the raw name of the dylib
        dylib_no_path = os.path.splitext(os.path.basename(dylib_path))[0]
        # if the dylib contains a versioning extension,
        # remove it
        if '-1.0' in dylib_no_path:
            self.dylib = dylib_no_path.split('-')[0]
        else:
            self.dylib = dylib_no_path

        log_info('creating module: {}'.format(self.dylib))
        
        self.framework_name = self.dylib
        # save to name for record keeping
        self.name = self.dylib

        # set the framework path and make our dylib.framework
        # directory
        self.framework_path = '{}.framework'.format(self.framework_name)
        os.makedirs(self.framework_path)
        self.abs_path = os.path.abspath(self.framework_path)
        # copy the dylib to the new path, then `cd` in
        copy2(dylib_path, '{}/{}'.format(self.framework_path, self.dylib))
        os.chdir(self.framework_path)

        # fix run paths, since we will be 
        # encapsulating each dylib
        self.__fix_rpaths()

        os.chdir('..')

    def __fix_rpaths(self):
        """Change the rpaths of a given dylib.

        Change the rpaths to match our framework
        encapsulations, essentially keeping the run paths
        intact.
        """
        log_info('fixing rpaths')
        # list the rpaths of this dylib
        rpaths = Popen(['otool', '-L', self.dylib], stdout=PIPE).communicate()[0]
        
        # iterate through each rpath
        # (ignore the first two lines, as this
        # output is purely informative)
        change_dylib_identification_name(
                id='@rpath/{}.framework/{}'.format(self.framework_name, self.dylib),
                dylib_path=self.dylib)
        for rpath in rpaths.splitlines()[2:]:
            if rpath.strip().startswith('@rpath'):
                match = re.match(r'.*@rpath\/(.*).dylib', rpath)
                if match is not None:
                    raw_dylib = match.group(1)
                    real_rpath = re.match(r'.*@rpath\/.*.dylib', rpath.strip()).group(0)
                    change_dylib_rpath(
                        old_rpath=real_rpath,
                        new_rpath='@rpath/{}.framework/{}'.format(raw_dylib, raw_dylib),
                        dylib_path=self.dylib
                    )

class FrameworkModule(Framework):
    """A Framework Module that encapsulates our embedded SDKs.

    See 
    https://clang.llvm.org/docs/Modules.html
    for more information.

    This differentiates from a standard Framework in that a modulemap
    and headers are supplied, so that it can be imported within
    Swift code.

    Arguments:
        dylib_path: str: the path to the dylib to Framework-ify
        module: ~Module object to be framework-ified
    """
    def __init__(self, dylib_path, module):
        super(FrameworkModule, self).__init__(dylib_path)

        log_info('creating framework module: {}'.format(module.name))

        self.module = module

        # add headers to the appropriate directory
        self.__add_headers(
            headers=glob(
                '{}/../include/{}'.format(os.path.dirname(dylib_path), module.headers)), 
            framework_headers_path='{}/Headers'.format(self.framework_path))
        
        # create and add module map to the appropriate directory
        self.__add_module_map(
            framework_modules_path='{}/Modules'.format(self.framework_path))
        
        # create and add info plist to the appropriate directory
        self.__add_info_plist()

    @property
    def __module_map(self):
        """.modulemap text for this Module"""        
        return """framework module {} [system] {{
        umbrella header "{}"
        export *
        module * {{ export * }}
        }}""".format(self.module.name, self.module.umbrella_header).strip()

    def __add_module_map(self, framework_modules_path):
        """Create and add a modulemap to the framework_modules_path"""
        log_info('adding modulemap')

        os.makedirs(framework_modules_path)
        module_map_filepath = '{}/module.modulemap'.format(framework_modules_path)
        open(module_map_filepath, 'w').write(self.__module_map)

    def __sanitize_header(self, header_path):
        """Sanitize headers to refer to the framework format.
        
        Angled includes must be prepended with the name of
        the module to function properly within the framework
        format.

        Arugments:
            header_path: str: path to the header file
        """
        # read the header file
        header = open(header_path).read()
        lines = []
        # iterate through each line,
        # replacing includes statements if
        # necessary
        for line in header.splitlines():
            new_line = line
            # check our known modules to see
            # if any of the includes have a known import
            for module in Modules.modules:
                if module.unmangled_import in line:
                    new_line = line.replace(
                        module.unmangled_import, 
                        '<{}/{}>'.format(module.name, module.umbrella_header))
            lines.append(new_line)
        # write out sanitized text to the original file
        open(header_path, 'w').write('\n'.join(lines))

    def __add_headers(self, headers, framework_headers_path):
        """Add sanitizied headers to the framework_headers_path"""

        log_info('adding headers')

        os.makedirs(framework_headers_path)

        # copy each header and then sanitize it
        for header in headers:
            copy2(header, framework_headers_path)
            self.__sanitize_header('{}/{}'.format(framework_headers_path, os.path.basename(header)))

    @property
    def __info_plist(self):
        """Info plist containing the required framework info"""
        output = Popen([
            'codesign', 
            '-dv', 
            '{}/{}'.format(self.framework_path, self.module.name)
        ], stderr=PIPE).communicate()[1].splitlines()
        identifier = [line.split('=')[1] for line in output if line.strip().startswith('Identifier')][0]
        return """<?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleExecutable</key>
        <string>{}</string>
        <key>CFBundleIdentifier</key>
        <string>{}</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        </dict>
        </plist>""".format(self.module.name, identifier).strip()

    def __add_info_plist(self):
        """Create and add and Info plist to the framework path"""

        log_info('adding Info.plist')

        open('{}/Info.plist'.format(self.framework_path), 'w').write(
            self.__info_plist)

class Module:
    """A module to be turned into a framework module
    
    Arguments:
        name: str: name of the module
        dylib: str: dylib to be encapsulated
        headers: str: globbed headers from our includes path
        umbrella_header: str: name of the file to be used as the umbrella header
        unmangled_import: the original includes before framework-ifying 
    """
    def __init__(self, name, dylib, headers, umbrella_header, unmangled_import):
        self.name = name
        self.dylib = dylib
        self.headers = headers
        self.umbrella_header = umbrella_header
        self.unmangled_import = unmangled_import

class Modules:
    """Enumeration of known modules"""
    libbson = Module(
        'libbson', 'libbson-1.0.dylib', 'libbson-1.0/*.h', 'bson.h', '<bson.h>')
    libmongoc = Module(
        'libmongoc', 'libmongoc-1.0.dylib', 'libmongoc-1.0/*.h', 'mongoc.h', '<mongoc.h>')
    libmongo_embedded_capi = Module(
        'libmongo_embedded_capi',
        'libmongo_embedded_capi.dylib',
        'mongo/embedded-v1/mongo/embedded/capi.h',
        'capi.h',
        '<mongo/embedded/capi.h>')
    libmongo_embedded_mongoc_client = Module(
        'libmongo_embedded_mongoc_client',
        'libmongo_embedded_mongoc_client.dylib',
        'mongo/embedded-v1/mongo/embedded/mongoc_client.h',
        'mongoc_client.h',
        '<mongo/embedded/mongoc_client.h>')
    # list of known modules
    modules = [libbson, libmongoc, libmongo_embedded_capi, libmongo_embedded_mongoc_client]
    # dict of module names to itself
    modules_map = dict((mod.dylib, mod) for mod in modules)
    # list of unmangled imports
    modules_unmangled_imports = list(map(lambda mod: mod.unmangled_import, modules))

class SDK:
    """An SDK for a given platform.

    Each platform contains variants. Each variant
    has associated SDKs that will be framework-ified.

    This class encapsulates, downloads, and framework-ifies
    those SDKs.

    Arguments:
        platform: ~Platform to be worked with
    """ 
    def __init__(self, platform):
        self.platform = platform
        for variant in platform.variants:
            # download the variant's SDK
            if os.path.exists(variant.name) is False:
                self.__download(variant)
                self.__fix_mongoc_symlinks(variant)
            else:
                log_warning(
                    'not downloading {}: already exists'.format(variant.name))

    def build_frameworks(self):
        """Build frameworks for this platform."""
        # create a frameworks path to store frameworks
        frameworks_path = 'Frameworks/{}'.format(self.platform.full_name)
        try:
            os.mkdir(frameworks_path)
        except:
            log_warning('Frameworks dir already exists')
            return
        
        q = Queue()

        # process each framework for each variant
        for variant in self.platform.variants:
            # set this variant's framework path
            variant_frameworks_path = '{}/{}'.format(frameworks_path, variant.name)
            
            os.mkdir(variant_frameworks_path)
            os.chdir(variant_frameworks_path)

            def __create_framework(queue, platform, variant, dylib):
                """Create the framework for a given dylib."""
                # read the path to actual dylib
                dylib_path = '../../../{}/lib/{}'.format(variant.name, dylib)
                if dylib in Modules.modules_map:
                    queue.put(FrameworkModule(dylib_path, Modules.modules_map[dylib]))
                elif with_mobile:
                    queue.put(Framework(dylib_path))
            
            processes = []
            # for each dylib, create a new process
            # that creates our framework
            for dylib in os.listdir('../../../{}/lib'.format(variant.name)):
                platform = self.platform
                processes.append(
                    Process(target=__create_framework, args=(q, platform, variant, dylib)))
                if len(processes) == 5:
                    map(lambda process: process.start(), processes)
                    map(lambda process: process.join(), processes)
                    processes = []

            os.chdir('../../..')

        frameworks = []
        # read our frameworks from the process
        # result queue
        while q.empty() is not True:
            frameworks.append(q.get())

        # map frameworks by name
        fmks = dict((fmk.name, []) for fmk in frameworks)
        for framework in frameworks:
            fmks[framework.name].append(framework)
        
        return fmks

    def __fix_mongoc_symlinks(self, variant):
        """Fix the symlinked libraries and their rpaths.
        
        This is done to avoid doubling up on libraries.

        Arguments:
            variant: Variant: ~Variant of these dylibs
        """
        os.remove('{}/lib/libbson-1.0.dylib'.format(variant.name))
        copyfile(
            '{}/lib/libbson-1.0.0.dylib'.format(variant.name),
            '{}/lib/libbson-1.0.dylib'.format(variant.name))
        os.remove('{}/lib/libmongoc-1.0.dylib'.format(variant.name))
        copyfile(
            '{}/lib/libmongoc-1.0.0.dylib'.format(variant.name),
            '{}/lib/libmongoc-1.0.dylib'.format(variant.name))
        os.remove('{}/lib/libbson-1.0.0.dylib'.format(variant.name))
        os.remove('{}/lib/libmongoc-1.0.0.dylib'.format(variant.name))
        os.remove('{}/lib/libbson-1.0.1.dylib'.format(variant.name))
        os.remove('{}/lib/libmongoc-1.0.1.dylib'.format(variant.name))

        change_dylib_identification_name(
            id='@rpath/libmongoc.framework/libmongoc',
            dylib_path='{}/lib/libmongoc-1.0.dylib'.format(variant.name))
        change_dylib_rpath(
            old_rpath='@rpath/libbson-1.0.1.dylib',
            new_rpath='@rpath/libbson.framework/libbson',
            dylib_path='{}/lib/libmongoc-1.0.dylib'.format(variant.name))

    def __download(self, variant):
        """Download the embedded sdk for this variant
        
        Argument:
            variant: Variant: ~Variant to be downloaded
        """
        tarball_name = 'mobile-sdks.tgz'
        log_info('downloading {}'.format(variant.name))

        # read and report on our download
        def chunk_report(bytes_so_far, chunk_size, total_size):
            percent = float(bytes_so_far) / total_size
            percent = round(percent*100, 2)
            sys.stdout.write(u"\u001b[36mdownloaded %d of %d bytes (%0.2f%%)\u001b[0m\r" % 
                (bytes_so_far, total_size, percent))

            if bytes_so_far >= total_size:
                sys.stdout.write('\n')

        def chunk_read(response, chunk_size=8192, report_hook=None):
            total_size = response.info().getheader('Content-Length').strip()
            total_size = int(total_size)
            bytes_so_far = 0
            chunks = []
            while 1:
                chunk = response.read(chunk_size)
                chunks.append(chunk)
                bytes_so_far += len(chunk)

                if not chunk:
                    break

                if report_hook:
                    report_hook(bytes_so_far, chunk_size, total_size)

            return [chunk for subchunk in chunks for chunk in subchunk]
        
        bytes = chunk_read(urllib2.urlopen(variant.url), report_hook=chunk_report)
        response = "".join(bytes)
        open(tarball_name, 'w+').write(response)
        os.mkdir(variant.name)
        tar = tarfile.open(tarball_name)
        # extract our needed members
        for member in tar.getmembers():
            if member.name.endswith('.dylib') or member.name.endswith('.h'):
                tar.extract(path=variant.name, member=member)

        tar.close()

        # copy the directories to the top level
        # and then remove the artifacts
        top_level = os.listdir(variant.name)[0]
        copytree(
            '{}/{}/lib'.format(variant.name, top_level),
            '{}/lib'.format(variant.name))
        copytree(
            '{}/{}/include'.format(variant.name, top_level), 
            '{}/include'.format(variant.name))
        rmtree('{}/{}'.format(variant.name, top_level))
        os.remove(tarball_name)

## BEGIN ##
parser = argparse.ArgumentParser()
parser.add_argument('-wm',
                    '--with-mobile',
                    default=False,
                    help='with non-modular mobile frameworks (beta)')
parser.add_argument('-osx',
                    '--with-osx',
                    default=False,
                    help='with osx embedded architectures')
parser.add_argument('-v',
                    '--verbose',
                    default=False,
                    help='verbose logging')
args = parser.parse_args()

with_mobile = args.with_mobile
with_osx = args.with_osx
verbose = args.verbose

if with_mobile is False:
    del Modules.modules_map[Modules.libmongo_embedded_capi.dylib]
    del Modules.modules_map[Modules.libmongo_embedded_mongoc_client.dylib]
if with_osx is False:
    Platforms.platforms.remove(Platforms.macosx)

if os.path.exists('Frameworks'):
    log_warning('Frameworks directory exists; exiting')
    exit(0)

os.mkdir('Frameworks')

# for each platform
for platform in Platforms.platforms:
    # build the frameworks for each variant
    fmks = SDK(platform).build_frameworks()
    # for each framework
    for name, fmk_list in fmks.iteritems():
        # lipo each variant together
        lipo(platform, fmk_list)
    # remove the unlipo'd artifacts
    rmtree('Frameworks/{}'.format(platform.full_name))
