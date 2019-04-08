
import subprocess
import re

simctls = subprocess.Popen("xcrun simctl list", shell=True, stdout=subprocess.PIPE).stdout.read()
device = re.findall("\w*com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-\w*(?!\s--)",simctls,re.MULTILINE)[-1]
runtime = re.findall("\w*com\.apple\.CoreSimulator\.SimRuntime\.iOS-\d*-\d(?!\s--)",simctls,re.MULTILINE)[-1]
print subprocess.Popen("xcrun simctl create __stitch__ %s %s" % (device, runtime), shell=True, stdout=subprocess.PIPE).stdout.read().rstrip()
