from frameworks import SwiftFrameworkModule
from modules import SwiftModule
from util import log_error, log_info

import os
from shutil import copy2, copytree, rmtree
from subprocess import call

class SwiftSource:
    def __init__(self, name, source_paths, frameworks_search_paths = None):
        self.name = name
        self.source_paths = source_paths
        self.framework_search_paths = frameworks_search_paths

    def create_module(self, platform, variant, min_platform_version):
        module_dir = self.__build_for(platform, variant, min_platform_version)
        
        return SwiftModule(
            self.name,
            platform,
            variant,
            library_path='{}/{}'.format(module_dir, self.name),
            headers=['{}/{}.h'.format(module_dir, self.name)],
            swiftdoc='{}/{}.swiftdoc'.format(module_dir, self.name),
            swiftmodule='{}/{}.swiftmodule'.format(module_dir, self.name))

    def __build_for(self, platform, variant, min_platform_version):
        if os.path.exists('.tmp') is False:
            os.mkdir('.tmp')
        if os.path.exists('.tmp/{}'.format(self.name)) is False:
            os.mkdir('.tmp/{}'.format(self.name)) 
        module_dir = '.tmp/{}/{}'.format(self.name, variant.name)
        os.mkdir(module_dir)

        cmd = ['xcrun', '-sdk', variant.name, 'swiftc']
        if self.framework_search_paths is not None:
            cmd += ['-F./{}'.format(self.framework_search_paths)]
        cmd += self.source_paths
        cmd += [
            '-o',
            '{}/{}'.format(module_dir, self.name),
            '-target',
            '{}-apple-{}{}'.format(variant.arch, platform.name, min_platform_version)]
        cmd += ['-emit-module', '-emit-objc-header', '-emit-library']

        if call(cmd) is not 0:
            return log_error('could not build {} from source').format(self.name)

        return module_dir