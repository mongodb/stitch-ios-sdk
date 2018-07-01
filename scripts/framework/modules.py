class Module(object):
    """A module to be turned into a framework module
    
    Arguments:
        name: str: name of the module
        library_path: str: path to library file to be encapsulated
        headers: str: globbed headers from our includes path
        umbrella_header: str?: name of the file to be used as the umbrella header
        unmangled_import: str?: the original includes before framework-ifying 
    """
    def __init__(
        self,
        name, 
        library_path, 
        headers,
        umbrella_header = None,
        submodules = []):
        self.name = name
        self.library_path = library_path
        self.headers = headers
        self.umbrella_header = umbrella_header
        self.submodules = submodules

class SwiftModule(Module):
    def __init__(
        self,
        name,
        platform,
        variant,
        library_path,
        headers,
        swiftdoc,
        swiftmodule):
        super(SwiftModule, self).__init__(name, library_path, headers)
        self.platform = platform
        self.variant = variant
        self.swiftdoc = swiftdoc
        self.swiftmodule = swiftmodule