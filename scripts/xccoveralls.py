import argparse
import hashlib
import json
import os
import re

from glob import glob
from hashlib import md5
from itertools import chain
from multiprocessing import Pool
from sys import argv
from typing import Dict

def log_error(msg: str):
    print('\u001b[31merror: {}\u001b[0m'.format(msg))

def log_warning(msg: str):
    print('\u001b[93mwarning: {}\u001b[0m'.format(msg))

def log_info(msg: str):
    print('\u001b[94minfo: {}\u001b[0m'.format(msg))

class LlvmCoverageClass():
    """An invidual class within a coverage report.
    
    Arguments:
        project_source_files: [str]: an array of source file paths
        source: str: actual source of the file being covered
    """
    def __init__(self, project_source_files: [str], source: str):
        self.project_source_files = project_source_files
        self.source = source
        self.line_coverage_data = list(
            map(self.__coverage_for_line,
                source.splitlines()))

    @property
    def is_path_on_first_line(self) -> bool:
        """Whether or not the path of the file is included in the report.

        Llvm coverage reports contain a filepath on the first line
        of the class being tested if and only if multiple classes
        are being tested, otherwise, we have to find the correct
        file.

        Returns:
            bool: True if filepath is included in report, False if not
        """
        path = self.source.split("\n")[0].replace(":", "")
        return path.lstrip().startswith("1|") is False

    @property
    def raw_source(self) -> str:
        """Return a report stripped of all coverage artifacts.

        Class reports contain a prefix with the line number,
        followed by the coverage number. We need the raw
        source to compare the checksum to the original file.

        Returns:
            str: The raw source of the covered file.
        """
        return '\n'.join(list(
            map(lambda line: line.split('|')[-1],
                self.source.splitlines())))

    @property
    def source_file_path(self) -> bytes:
        """Find the filepath for the file tests from the report.
        
        See #is_path_on_first_line for more details.

        Returns:
            bytes: filepath for the source file
        """
        if self.is_path_on_first_line:
            return self.source.split("\n")[0].replace(":", "").encode('utf-8')
        else:
            # if llvm-cov was run with just one matching source file
            # it doesn't print the source path in this case,.
            # we have to find it ourselves.
            digest = md5()
            digest.update(self.raw_source.encode('utf-8'))
            our_hex = digest.digest()
            for file in self.project_source_files:
                if file is None or file is '':
                    continue
                digest = md5()
                digest.update(open(file).read().encode('utf-8'))
                file_hex = digest.digest()
                # compare checksums
                if our_hex == file_hex:
                    return os.fsencode(file)

    @property
    def payload(self) -> Dict[str, any]:
        """Create a new payload to send to coveralls.

        The payload is a hash representing a source code file and
        its coverage data for a single job.

        Returns:
            Dict[str, any]: payload to be sent to coveralls
        """
        return {
            'name': os.path.relpath(self.source_file_path).decode('utf-8'),
            'source_digest': md5(self.source.encode('utf-8')).hexdigest(),
            'coverage': self.line_coverage_data
        }

    def __coverage_for_line(self, line: str) -> int:
        """Parse coverage count for a given line of code.
        
        Each line contains a prefix with the line number
        and coverage count. Fetch the coverage count.

        Arguments:
            line: str: line of code to be parsed
        Returns:
            int: coverage count of the line
        """
        line = re.sub(":", "|", line)

        match = re.match(r'.*(\s*)(\d*)\|(\s*)(\d+)', line)
        if match is not None:
            group = match.group(4)

        if match is None or group is None:
            # check for thousands or millions (llvm-cov outputs hit counts as 25.3k or 3.8M)
            did_match = re.match(r'/^(\s*)(\d+)\|(\s*)(\d+\.\d+)(k|M)\|/', line)

            if did_match is not None:
                group = did_match.group(4)
                units_group = did_match.group(5)
                count = group.strip()
                units = 1000 if units_group == 'k' else 1000000
                int((float(count) * units))
            else:
                return None
        else:
            match = group.strip()
            if re.search(r'[0-9]+', match) is not None:
                return int(match)
            elif re.search(r'#+', match) is not None:
                return 0
            else:
                return None  

class LlvmCoverageReport():
    """A full coverage report containing 'n' files covered.
    
    Arguments:
        source_paths: [str]: an array of source file paths
        raw_coverage_data: str: the raw coverage report
    """
    def __init__(self, source_paths: [str], raw_coverage_data: str):
        self.source_paths = source_paths
        self.raw_coverage_data = raw_coverage_data
        self.coverage_classes: [LlvmCoverageClass] = []
        # this check determines if the profdata was
        # generated from a single file
        if self.is_path_on_first_line is False:
            self.coverage_classes = [LlvmCoverageClass(source_paths, raw_coverage_data)]
        else:
            self.coverage_classes = list(
                map(lambda lines: LlvmCoverageClass(source_paths, lines),
                    self.raw_coverage_data.split("\n\n")[:-1]))

    @property
    def payload(self) -> [Dict[str, any]]:
        """Create a new payload to send to coveralls.

        The payload is an array of hashes representing the source
        code files and its coverage data for a single job.

        Returns:
            Dict[str, any]: payload to be sent to coveralls
        """
        return list(map(lambda cov: cov.payload, self.coverage_classes))
            
    @property
    def is_path_on_first_line(self) -> bool:
        """Whether or not the path of the file is included in the report.

        Llvm coverage reports contain a filepath on the first line
        of the class being tested if and only if multiple classes
        are being tested, otherwise, we have to find the correct
        file.

        Returns:
            bool: True if filepath is included in report, False if not
        """
        path = self.raw_coverage_data.split("\n")[0].replace(":", "")
        return path.lstrip().startswith("1|") is False

def find_file(filename: str, directory: bytes) -> bytes:
    """Find a filename recursively within a given directory.
    
    Arguments:
        filename: str: name of the file to be found (without path)
        directory: bytes: top level directory to be searched

    Returns:
        bytes: absolute path to file
    """
    for root, dirs, filenames in os.walk(directory):
        if os.fsencode(filename) in filenames:
            return os.path.abspath(os.path.join(root, os.fsencode(filename)))
        for dir in dirs:
            find_file(filename, os.path.join(root, dir))

def map_coverage_files_to_coverage_payloads(file: bytes) -> [Dict[str, any]]:
    """Map raw coverage files to their parsed payloads.

    Arguments:
        file: bytes: path to coverage file

    Returns:
        [Dict[str, any]]: an array containing each parsed coverage class
    """
    xcproject_name = os.path.splitext(file)[0]
    log_info('finding file map for {}'.format(xcproject_name))
    filepath = find_file(
        '{}-OutputFileMap.json'.format(xcproject_name), 
        os.fsencode('{}/Build/Intermediates.noindex'.format(derived_data_dir)))
    source_paths = list(map(
        lambda filename: filename,
        json.loads(open(filepath).read())))
    log_info('parsing llvm coverage report for {}'.format(xcproject_name))
    return LlvmCoverageReport(
        source_paths, 
        open(os.path.join(coverage_data_dir, file)).read()).payload

def send_payload_to_coveralls(payload_json: str):
    from urllib import request, parse
    url = 'https://coveralls.io/api/v1/jobs'
    req = request.Request(url, data=parse.urlencode({ 'json': payload_json }).encode('utf-8'))
    return request.urlopen(req)

"""
Find and parse coverage files into coveralls payload.
Deliver to coveralls.
"""
parser = argparse.ArgumentParser()
parser.add_argument('-rt',
                    '--repo-token',
                    help='the repo_token provided for your coveralls repo')
parser.add_argument('-dd',
                    '--derived-data-dir',
                    help='the path to your derived data directory')
parser.add_argument('-cd',
                    '--coverage-data-dir',
                    help='the directory where coverage data has been generated')
parser.add_argument('-pr',
                    '--pull-request-id',
                    help='the associated pull request id of the build')
parser.add_argument('-b',
                    '--build-number',
                    help='the number of this build')
parser.add_argument('-sha',
                    '--commit-sha',
                    help='the sha of this git commit')
args = parser.parse_args()

from datetime import datetime

start = datetime.now()

repo_token = args.repo_token
coverage_data_dir = args.coverage_data_dir
derived_data_dir = args.derived_data_dir
pull_request_id = args.pull_request_id
build_number = args.build_number
commit_sha = args.commit_sha

if repo_token is None:
    log_error(
        'must provide repo token. please see --help for more info')
    exit(1)
if coverage_data_dir is None:
    coverage_data_dir = './CoverageData'
    log_warning(
        'coverage data directory not provided. defaulting to ./CoverageData')
if derived_data_dir is None:
    derived_data_dir = './localDerivedData'
    log_warning(
        'derived data directory not provided. defaulting to ./localDerivedData')

with Pool(processes=4) as p:
    coverage_payloads = p.map(
        map_coverage_files_to_coverage_payloads,
        os.listdir(coverage_data_dir))

    payload_json = json.dumps({
        'repo_token': repo_token,
        'service_name': 'evergreen',
        'service_number': build_number,
        'service_pull_request': pull_request_id,
        'commit_sha': commit_sha,
        'source_files': list(chain(*coverage_payloads)),
    })

    log_info('coveralls response: {}'.format(send_payload_to_coveralls(payload_json).read()))
    end = datetime.now()
    log_info('xccoveralls took {} to run'.format(end - start))
