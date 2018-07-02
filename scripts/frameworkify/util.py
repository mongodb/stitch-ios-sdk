from subprocess import call

_VERBOSE = False
def set_verbosity(verbosity):
    _VERBOSE = verbosity

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
    if _VERBOSE:
        print u'\u001b[94minfo: {}\u001b[0m'.format(msg)


def change_library_identification_name(id, library_path):
    """Change the identification name of a given dylib.

    Use the `install_name_tool` command to change the
    identification name of a given dylib.

    Arguments:
        id: str: id to change to
        dylib_path: str: path to the dylib
    """
    if call(['install_name_tool', '-id', id, library_path]) is not 0:
        log_error('could not change id of dylib: {}'.format(library_path))

def change_library_rpath(old_rpath, new_rpath, library_path):
    """Change an rpath name of a given dylib.

    Use the `install_name_tool` command to change an
    rpath of a given dylib.

    Arguments:
        old_rpath: str: rpath to change
        new_rpath: str: rpath to change to
        dylib_path: str: path to the dylib
    """
    if call(['install_name_tool', '-change', old_rpath, new_rpath, library_path]) is not 0:
        log_error('could not change rpath of dylib: {}'.format(library_path))