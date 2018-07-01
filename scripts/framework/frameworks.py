"""
Download embedded mongo SDKs and covert
the dylibs into .frameworks.
"""
from __main__ import FRAMEWORKS_DIR
from modules import SwiftModule
from platforms import platforms
from util import log_error, log_warning, log_info, change_library_identification_name, change_library_rpath

import os
import re
import sys
import tarfile
import urllib2

from multiprocessing import Process, Queue
from shutil import copy2, copytree
from subprocess import Popen, PIPE, call


class Framework(object):
    """A Framework that encapsulates our embedded SDKs.

    See 
    https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/WhatAreFrameworks.html
    for more information.

    Arguments:
        library_path: str: the path to the executable to Framework-ify
        should_fix_rpaths: bool: whether or not the rpaths are misaligned
    """
    def __init__(self, name, library_path, should_fix_rpaths):
        self.name = name
        self.library_path = library_path
        self.should_fix_rpaths = should_fix_rpaths
        self.is_created = False

    def create(self, platform, variant):
        log_info('creating framework: {}'.format(self.name))
        self.framework_path = '{}/{}/{}/{}.framework'.format(
            FRAMEWORKS_DIR, platform.full_name, variant.name, self.name)
        self.bin_path = '{}/{}'.format(self.framework_path, self.name)
        # set the framework path and make our dylib.framework
        # directory
        os.makedirs(self.framework_path)
        self.abs_path = os.path.abspath(self.framework_path)
        # copy the binary to the new path
        copy2(self.library_path, self.bin_path)

        # fix run paths, since we will be 
        # encapsulating each dylib
        if self.should_fix_rpaths:
            self.__fix_rpaths()

        self.is_created = True
        return self

    def lipo(self, platform, *frameworks):
        """Lipo frameworks that share the same sdk/arch

        Create a framework that combines the variants
        of a given platform.

        Arguments:
            platform: Platform: ~Platform to build for
            frameworks: [Framework]: list of frameworks to lipo
        """
        if len(frameworks) is 0:
            return log_error('cannot lipo: no frameworks created')

        # add tupled self
        frameworks = frameworks + (self,)
        
        if reduce(lambda a,b: a.is_created and b.is_created, frameworks) is False:
            return log_error('cannot lipo: not all frameworks created')

        cmd = ['lipo', '-create'] + map(
            lambda framework: framework.bin_path,
            frameworks)
        # output everything to the initial fmk. this is
        # arbitrary. we are going to move everything to
        # the top level anyway
        cmd += ['-o', '{}/{}'.format(self.abs_path, self.name)]

        # call the lipo command
        call(cmd)

        # copy them to the new top level
        copytree(
            self.abs_path,
            'Frameworks/{}/{}.framework'.format(
                platform.name, self.name))

    def __fix_rpaths(self):
        """Change the rpaths of a given dylib.

        Change the rpaths to match our framework
        encapsulations, essentially keeping the run paths
        intact.
        """
        log_info('fixing rpaths')
        # list the rpaths of this dylib
        rpaths = Popen(['otool', '-L', '{}/{}'.format(self.framework_path, self.name)], stdout=PIPE).communicate()[0]
        
        # iterate through each rpath
        # (ignore the first two lines, as this
        # output is purely informative)
        change_library_identification_name(
                id='@rpath/{}.framework/{}'.format(self.name, self.name),
                library_path=self.bin_path)
        for rpath in rpaths.splitlines()[2:]:
            if rpath.strip().startswith('@rpath'):
                match = re.match(r'.*@rpath\/(.*).dylib', rpath)
                if match is not None:
                    raw_dylib = match.group(1)
                    real_rpath = re.match(r'.*@rpath\/.*.dylib', rpath.strip()).group(0)
                    change_library_rpath(
                        old_rpath=real_rpath,
                        new_rpath='@rpath/{}.framework/{}'.format(raw_dylib, raw_dylib),
                        library_path=self.bin_path)

class FrameworkModule(Framework):
    """A Framework Module that encapsulates our embedded SDKs.

    See 
    https://clang.llvm.org/docs/Modules.html
    for more information.

    This differentiates from a standard Framework in that a modulemap
    and headers are supplied, so that it can be imported within
    Swift code.

    Arguments:
        library_path: str: the path to the executable to Framework-ify
        module: Module: ~Module object to be framework-ified
    """
    def __init__(self, module):
        super(FrameworkModule, self).__init__(
            name=module.name,
            library_path=module.library_path,
            should_fix_rpaths=module is not SwiftModule)

        self.module = module

    def create(self, platform, variant):
        super(FrameworkModule, self).create(platform, variant)
        self.is_created = False
        log_info('creating framework module: {}'.format(self.module.name))

        self.framework_headers_path = '{}/Headers'.format(self.framework_path)
        self.framework_modules_path = '{}/Modules'.format(self.framework_path)
        # add headers to the appropriate directory
        self.__add_headers()
        
        # create and add module map to the appropriate directory
        self.__add_module_map()
        
        # create and add info plist to the appropriate directory
        self.__add_info_plist()

        self.is_created = True
        return self

    def __swift_module(self):
        pass

    def get_module_map(self):
        """.modulemap text for this Module"""
        return """framework module {} [system] {{
        umbrella header "{}"
        export *
        module * {{ export * }}
        }}""".format(
            self.module.name, 
            self.module.umbrella_header
        ).strip()
    
    def __add_module_map(self):
        """Create and add a modulemap to the framework_modules_path"""
        log_info('adding modulemap')

        os.makedirs(self.framework_modules_path)
        module_map_filepath = '{}/module.modulemap'.format(self.framework_modules_path)
        open(module_map_filepath, 'w').write(self.get_module_map())

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
            for submodule in self.module.submodules:
                angled_header = '<{}>'.format(submodule.umbrella_header)
                if angled_header in line:
                    new_line = line.replace(
                        angled_header,
                        '<{}/{}>'.format(submodule.name, submodule.umbrella_header))
            lines.append(new_line)
        # write out sanitized text to the original file
        open(header_path, 'w').write('\n'.join(lines))

    def __add_headers(self):
        """Add sanitizied headers to the framework_headers_path"""

        log_info('adding headers')

        os.makedirs(self.framework_headers_path)

        # copy each header and then sanitize it
        for header in self.module.headers:
            copy2(header, self.framework_headers_path)
            self.__sanitize_header('{}/{}'.format(self.framework_headers_path, os.path.basename(header)))

    @property
    def __info_plist(self):
        """Info plist containing the required framework info"""
        # fetch signature for identifier.
        # if unsigned, this will be None
        output = Popen([
            'codesign', 
            '-dv', 
            '{}/{}'.format(self.framework_path, self.module.name)
        ], stderr=PIPE).communicate()[1].splitlines()
        line = [line.split('=')[1] for line in output if line.strip().startswith('Identifier')]
        if len(line) > 0:
            identifier = line[0]
        else:
            identifier = self.module.name
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
        <key>CFBundleShortVersionString</key>
        <string>1.0.0</string>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        <key>MinimumOSVersion</key>
        <string>10.2</string>
        </dict>
        </plist>""".format(
            self.module.name,
            identifier).strip()

    def __add_info_plist(self):
        """Create and add and Info plist to the framework path"""

        log_info('adding Info.plist')

        open('{}/Info.plist'.format(self.framework_path), 'w').write(
            self.__info_plist)

class SwiftFrameworkModule(FrameworkModule):
    def __init__(self, swift_module):
        super(SwiftFrameworkModule, self).__init__(swift_module)

    def create(self):
        super(SwiftFrameworkModule, self).create(
            self.module.platform, self.module.variant)
        self.is_created = False
        self.swift_modules_path = '{}/{}.swiftmodule'.format(
            self.framework_modules_path, self.module.name)
        os.makedirs(self.swift_modules_path)

        self.__add_swift_doc()
        self.__add_swift_module()
        self.is_created = True
        return self

    def lipo(self, platform, *frameworks):
        # import specifically for copying files from
        # directory to another directory (this excludes
        # the directory itself)
        from distutils.dir_util import copy_tree

        map(lambda framework: copy_tree(
            framework.swift_modules_path,
            self.swift_modules_path), frameworks + (self,))

        super(SwiftFrameworkModule, self).lipo(platform, *frameworks)

    def get_module_map(self):
        """.modulemap text for this Module"""
        return """framework module {} {{
        header "{}"
        requires objc
        }}""".format(
            self.module.name, 
            os.path.basename(self.module.headers[0])
        ).strip()

    def __add_swift_doc(self):
        copy2(
            self.module.swiftdoc, 
            '{}/{}.swiftdoc'.format(
                self.swift_modules_path, 
                self.module.variant.arch if self.module.variant.arch is not "armv7k" else "arm"))
    
    def __add_swift_module(self):
        copy2(
            self.module.swiftmodule, 
            '{}/{}.swiftmodule'.format(
                self.swift_modules_path, 
                self.module.variant.arch if self.module.variant.arch is not "armv7k" else "arm"))
