"""The public interface to helium_client."""

from ._helium import (
    Helium,
    Channel,
    Info,
    POLL_RETRIES_5S,
    HeliumError,
    NoDataError,
    CommunicationError,
    NotConnectedError,
    DroppedError,
    KeepAwakeError,
    ChannelError
)
from ._version import get_versions
__version__ = get_versions()['version']
del get_versions

__all__ = (
    'Helium',
    'POLL_RETRIES_5S'
    'Info',
    'Channel',
    'HeliumError',
    'NoDataError',
    'CommunicationError',
    'NotConnectedError',
    'DroppedError',
    'KeepAwakeError',
    'ChannelError'
)
