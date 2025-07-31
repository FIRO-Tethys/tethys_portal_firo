from tethys_sdk.base import TethysExtensionBase


class Extension(TethysExtensionBase):
    """
    Tethys extension class for Default Theme.
    """

    name = 'Default Theme'
    package = 'default_theme'
    root_url = 'default-theme'
    description = 'Theme for the FIRO portal'