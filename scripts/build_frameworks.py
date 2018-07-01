from framework import (
    FRAMEWORKS_DIR,
    FrameworkModule, 
    Module,
    iphone,
    watch,
    appletv,
    macos,
    platforms, 
    SwiftSource, 
    SwiftFrameworkModule,
    VERBOSE)
 
from framework.util import (
    change_library_identification_name, 
    change_library_rpath,
    log_warning, 
    log_error,
    log_info)

import os
import sys
import tarfile
import urllib2

from glob import glob
from shutil import copy2, copyfile, copytree, rmtree

def embedded_sdk_url(variant, min_version):
    """The url to download the embedded SDK for this variant."""
    return (
        'https://s3.amazonaws.com/mciuploads/mongodb-mongo-v4.0'
        '/embedded-sdk/embedded-sdk-{}-{}-latest.tgz'.format(
            variant.name,
            min_version))

def fix_mongoc_symlinks(variant):
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

    try:
        os.remove('{}/lib/libbson-1.0.1.dylib'.format(variant.name))
        os.remove('{}/lib/libmongoc-1.0.1.dylib'.format(variant.name))
    except:
        # these files may not exist
        pass
    change_library_identification_name(
        id='@rpath/libmongoc.framework/libmongoc',
        library_path='{}/lib/libmongoc-1.0.dylib'.format(variant.name))
    change_library_rpath(
        old_rpath='@rpath/libbson-1.0.1.dylib',
        new_rpath='@rpath/libbson.framework/libbson',
        library_path='{}/lib/libmongoc-1.0.dylib'.format(variant.name))

def download(variant, min_version):
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
    
    bytes = chunk_read(urllib2.urlopen(embedded_sdk_url(variant, min_version)), report_hook=chunk_report)
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

VERBOSE = True

platform_to_min_version = {
    iphone: 10.2,
    appletv: 10.2,
    watch: 4.3,
    macos: '10.10' # float point
}

# for each platform
for platform in platforms:
    if os.path.exists('{}/{}'.format(FRAMEWORKS_DIR, platform.name)):
        log_warning(
            'not building {}: already exists'.format(platform.name))
        continue
    # build the frameworks for each variant
    bson_frameworks = []
    mongoc_frameworks = []
    mongoswift_frameworks = []

    min_version = platform_to_min_version[platform]

    for variant in platform.variants:
        if os.path.exists(variant.name) is False:
            download(variant, min_version)
            fix_mongoc_symlinks(variant)
        else:
            log_warning(
                'not downloading {}: already exists'.format(variant.name))

        libbson = Module(
            name='libbson',
            library_path='{}/lib/libbson-1.0.dylib'.format(variant.name),
            headers=glob('{}/include/libbson-1.0/*.h'.format(variant.name)), 
            umbrella_header='bson.h')
        libmongoc = Module(
            'libmongoc', 
            '{}/lib/libmongoc-1.0.dylib'.format(variant.name),
            headers=glob('{}/include/libmongoc-1.0/*.h'.format(variant.name)),
            umbrella_header='mongoc.h',
            submodules=[libbson])
        mongoswift = SwiftSource(
            'MongoSwift', 
            glob('MongoSwift/*.swift') + glob('MongoSwift/BSON/*.swift'), 
            '{}/{}/{}'.format(FRAMEWORKS_DIR, platform.full_name, variant.name))

        bson_frameworks.append(FrameworkModule(libbson).create(platform, variant))
        mongoc_frameworks.append(FrameworkModule(libmongoc).create(platform, variant))
        mongoswift_frameworks.append(
            SwiftFrameworkModule(mongoswift.create_module(platform, variant, min_version)).create())

    if platform is not macos:
        # for each framework, lipo the variants
        # per platform together
        reduce(lambda a,b: a.lipo(platform, b), bson_frameworks)
        reduce(lambda a,b: a.lipo(platform, b), mongoc_frameworks)
        reduce(lambda a,b: a.lipo(platform, b), mongoswift_frameworks)
    else:
        map(lambda framework: copytree(
            framework.abs_path,
            '{}/{}/{}.framework'.format(FRAMEWORKS_DIR,
                platform.name, framework.name)), bson_frameworks + mongoc_frameworks + mongoswift_frameworks)
        
    # remove the artifacts
    rmtree('{}/{}'.format(FRAMEWORKS_DIR, platform.full_name))

rmtree('.tmp', ignore_errors=True)
# rmtree('MongoSwift', ignore_errors=True)