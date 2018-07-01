import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-F',
                    '--frameworks-dir',
                    default='Frameworks',
                    help='directory to create frameworks')
# parser.add_argument('')
parser.add_argument('-v',
                    '--verbose',
                    action='store_true',
                    help='verbose logging')
args = parser.parse_args()

VERBOSE = args.verbose
FRAMEWORKS_DIR = args.frameworks_dir
