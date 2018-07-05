from frameworks import SwiftFrameworkModule
from modules import SwiftModule
from util import log_error, log_info

import os
from shutil import copy2, copytree, rmtree
from subprocess import call, Popen, PIPE
import re
import json

class SwiftSource:
    def __init__(self, name, source_paths, frameworks_search_paths = None, flags = []):
        self.name = name
        self.source_paths = source_paths
        self.framework_search_paths = frameworks_search_paths
        self.flags = flags

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
        cmd += self.flags
        cmd += [
            '-o',
            '{}/{}'.format(module_dir, self.name),
            '-target',
            '{}-apple-{}{}'.format(variant.arch, platform.name, min_platform_version)]
        cmd += ['-emit-module', '-emit-objc-header', '-emit-library']

        print ' '.join(cmd)
        
        output = Popen(cmd, stderr=PIPE).stderr.read()
        
        output = re.sub(r'^\d+$', ',', output, flags=re.MULTILINE)
        
        if os.path.exists('OutputFileMaps') is False:
            os.mkdir('OutputFileMaps')

        if output is not None:
            if len(output.split('\n', 1)) > 1:
                output = json.loads('[{}]'.format(output.split('\n', 1)[1]))
                open('OutputFileMaps/{}-OutputFileMap.json'.format(self.name), 'w').write(
                    json.dumps(map(
                        lambda inner: inner['inputs'][0], 
                        filter(lambda obj: obj['name'] == 'compile' and 'inputs' in obj, output)))
                )
        
        return module_dir
