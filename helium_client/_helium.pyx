# cython: cdivision = True
# cython: boundscheck = False
# cython: wraparound = False
# cython: profile = False
# cython: embedsignature = True

from collections import namedtuple
from libc.string cimport strerror
from libc.errno  cimport errno
from libc.stdint cimport (
    intptr_t,
    uint32_t,
    uint16_t,
    uint8_t,
    int8_t
)


class Info(namedtuple('Info', 'mac uptime time fw_version radio_count')):
    """Represents information about a Helium Atom.

    Information on a :class:`Helium` instance can be retrieved by
    calling :meth:`.Helium.info`. The returned object has a number of
    attributes that describe the Atom.

    Attributes:

        mac (:obj:`int`): The MAC address of the Atom as an 8 byte integer.

        uptime (:obj:`int`): The number of seconds since the Atom has been
            last restarted.

        time (:obj:`int`): The current time in seconds since Unix Epoch of
            the Helium Atom. The value of this attribute will not be
            accurate until the Atom is connected to the Helium
            Network.

        fw_version (:obj:`int`): The version of the Atom as a 4 byte integer
            representing the ``<majon><minor><patch><extra>`` of the
            firmware version.

        radio_count (:obj:`int`): The number of radios present in the Atom.

    """
    __slots__ = ()

    def __repr__(self):
        template = "Helium <mac: {:08x} version: {:04x}>"
        return template.format(self.mac, self.fw_version)


class HeliumError(Exception):
    """The base error class for Helium related errors."""
    pass


class NoDataError(HeliumError):
    """Represents a failure getting data for a channel request."""
    pass


class CommunicationError(HeliumError):
    """Represents a failure communicating with the Helium atom."""
    pass


class NotConnectedError(HeliumError):
    """Represents not being connected to the network."""
    pass


class DroppedError(HeliumError):
    """Represents the request being dropped by the Helium Atom.

    This should not happen with reasonable use of the Helium
    Atom. This may occur when you send many requests quickly, the
    radio does not receive an acknowledgement of receipt by the
    Element, or the radio looses access to it's channel.

    """
    pass


class KeepAwakeError(HeliumError):
    """Represents pending data for the Helium Atom.

    This is most likely to happen when you try to put the Atom to
    sleep and there is a pending firmware update that is in progress.

    """
    pass


class ChannelError(HeliumError):
    """Represents an error response for a channel request."""
    pass


error_classes = {
    OK_NO_DATA:         NoDataError,
    ERR_DROPPED:        DroppedError,
    ERR_COMMUNICATION:  CommunicationError,
    ERR_NOT_CONNECTED:  NotConnectedError,
    ERR_KEEP_AWAKE:     KeepAwakeError
}


POLL_RETRIES_5S = _POLL_RETRIES_5S

def _error_for(status, message=None):
    klazz = error_classes.get(status, None)
    if klazz is None:
        klazz = HeliumError
    return klazz(message or status)


def _check_result(self, status, builder=None, message=None):
    if status == OK:
        return None if builder is None else builder()
    raise _error_for(status, message)


cdef class Helium:
    """The main class for communicating with the Helium atom.
    """

    cdef ctx _ctx

    def __cinit__(self, const char * device_file):
        self._ctx.param = <void *><intptr_t>0
        fd = open_serial_port(device_file, baud_9600)
        if fd < 0:
            raise CommunicationError(strerror(errno))
        init(&self._ctx, <void *><intptr_t>fd)

    def needs_reset(self):
        """Check whether the Atom needs a reset.

        Returns:

            :obj:`True` if the Helium Atom requires a reset in order
            to complete a firmware upgrade, :obj:`False` otherwise.

        """
        return needs_reset(&self._ctx)

    def info(self):
        """Get information on the Helium Atom.

        This gets current information on the Helium Atom this object
        is communicating with. The Atom does not have to be connected
        to the network for this method to be called.

        Returns:

            :class:`.Info` on the Helium Atom.
        """
        cdef info info
        cdef int status = _info(&self._ctx, &info)
        return _check_result(self, status, lambda: Info(**info))

    def connect(self, retries=POLL_RETRIES_5S):
        """Connect to the network.

        Tries to connect to the Helium Network. If after the give
        number of retries the Atom is not connected to the network a
        :class:`.NotConnectedError` is raised.

        :obj:`None` may be passed for ``retries`` in which case you
        can use :meth:`.connected` to check whether the atom is
        connected to the network.

        Args:

            retries (:obj:`int`, optional): The number of times to
                retry waiting for a response (defaults to about 5
                seconds)

        Raises:

            :class:`.HeliumError`: A HeliumError or a subclass if an
                error occurred.

        """
        return _check_result(self, connect(&self._ctx, NULL, retries))

    def connected(self):
        """Check if the Atom is connected to the network

        Returns:

            :obj:`True` if the Atom is connected to the network
            :obj:`False` otherwise

        """
        return connected(&self._ctx)

    def sleep(self):
        """Disconnect from the network.

        This disconnects the Atom from the network and attempts to put
        the Atom to sleep.


        Note:

            This method does not return anything but may raise a
            :class:`.HeliumErrror` or subclass representing the error
            that occurred. This should not happen in most cases, but if
            the Atom is expecting more data or is in the process of
            receiving an update an error may be raised and will need
            to be handled.

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred

        """
        return _check_result(self, sleep(&self._ctx, NULL))

    def close(self):
        """Close the port used to communicate with the Helium Atom.

        This closes the underlying serial port used to communicate
        with the Helium Atom.

        """
        cdef int fd = <int><intptr_t>self._ctx.param
        if fd != 0:
            close_serial_port(fd)

    def create_channel(self, channel_name, retries=POLL_RETRIES_5S):
        """Create a :class:`.Channel` for a given name.

        See Also:

            :meth:`.Channel.create` for details.
        """
        return Channel.create(self, channel_name, retries=retries)

    def _channel_response(self, status, token, retries=POLL_RETRIES_5S):
        if retries is None:
            return _check_result(self, status, lambda: token)

        cdef int8_t result
        if status == OK:
            status = channel_poll_result(&self._ctx, token, &result, retries)

        def _check_result_details():
            if result >= 0:
                return result
            else:
                raise ChannelError(result)

        return _check_result(self, status, _check_result_details)

    def _channel_create(self, channel_name, retries=POLL_RETRIES_5S):
        cdef uint16_t token
        cdef int status = channel_create(&self._ctx, channel_name, len(channel_name), &token)
        return self._channel_response(status, token, retries=retries)

    def _channel_send(self, channel_id, data, retries=POLL_RETRIES_5S):
        cdef uint16_t token
        cdef char * data_bytes = data
        cdef int status = channel_send(&self._ctx, channel_id, data_bytes, len(data), &token)
        return self._channel_response(status, token, retries=retries)

    def __enter__(self):
        return self

    def __exit__(self, a, b, tb):
        self.close()
        return True


class Channel(object):
    """Send and receive data to IoT back-end channels.

    A channel can be created by calling :meth:`.Channel.create` or
    using the convenience method :meth:`.Helium.create_channel`.

    """

    def __init__(self, helium, channel_id, channel_name=None):
        self._helium = helium
        self._channel_id = channel_id
        self._channel_name = channel_name

    @classmethod
    def create(cls, helium, channel_name, retries=POLL_RETRIES_5S):
        """Create a channel.

        Warning:

            Channel creation will only succeed if you have set up a
            channel on your Helium Dashboard.

        Args:

            helium (:class:`.Helium`): The Helium Atom to use for
                communication.

            channel_name (:obj:`str`): The name of the channel to create.

            retries (:obj:`int`, optional): The number of times to
                retry waiting for a response (defaults to about 5
                seconds)

        Returns:

            If `retries` is `None` a token representing the
            request. Use :meth:`.poll` to fetch the channel response at a
            later time.

            A :class:`.Channel` instance if retries is not `None`. If
            an error occurred or the number of retries is exhausted a
            :class:`.HeliumError` is raised.

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred

        """
        result = helium._channel_create(channel_name, retries=retries)
        if retries is None:
            return result

        return cls(helium, result, channel_name=channel_name)

    def send(self, data, retries=POLL_RETRIES_5S):
        """Send data on a channel.

        Sends data on a Helium Channel and waits for a given number of
        retries for a response from the channel.

        Args:

            data (:obj:`bytes`): Data to send to the channel.

            retries (:obj:`int`, optional): The number of times to retry
                waiting for a response (defaults to about 5 seconds)

        """
        self._helium._channel_send(self._channel_id, data,
                                   retries=retries)

    def poll(self, token, retries=POLL_RETRIES_5S):
        """Poll a channel for a result.

        Args:

            token (:obj:`int`): The token to check a result for.

            retries (:obj:`int`, optional): The number of times to retry
                waiting for a response (defaults to about 5 seconds).

        Returns:

            The response of the channel if successful. An exception is
            raised otherwise.

            For the :meth:`.create`` method this response will be the
            channel id of the created channel. For other channel
            methods the response will be ``0`` if successful. On any
            error a :class:`.ChannelError` is raised.

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred

        """
        return self._helium._channel_response(OK, token, retries=retries)

    def __repr__(self):
        return '{0} <name: {1} id: {2}>'.format(self.__class__.__name__,
                                                repr(self._channel_name),
                                                self._channel_id)
