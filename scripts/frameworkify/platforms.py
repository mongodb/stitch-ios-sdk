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
            arch: str: architecture to build for
        """
        def __init__(self, name, arch):
            self.name = name
            self.arch = arch

    def __init__(self, name, full_name, variants):
        self.name = name
        self.full_name = full_name
        self.variants = variants

"""Enumeration of available platforms"""
iphone = Platform(
    name='ios', 
    full_name='iphone', 
    variants=[
        Platform.Variant(name='iphoneos', arch='arm64'),
        Platform.Variant(name='iphonesimulator', arch='x86_64')])

appletv = Platform(
    name='tvos', 
    full_name='appletv', 
    variants=[
        Platform.Variant(name='appletvos', arch='arm64'),
        Platform.Variant(name='appletvsimulator', arch='x86_64')
    ])

watch = Platform(
    name='watchos',
    full_name='watch',
    variants=[
        Platform.Variant(name='watchos', arch='armv7k'),
        Platform.Variant(name='watchsimulator', arch='i386')
    ])

macos = Platform(
    name='macos',
    full_name='macosx',
    variants=[
        Platform.Variant(name='macosx', arch='x86_64')
    ])

# list of each platform
platforms = [iphone, appletv, watch, macos]
