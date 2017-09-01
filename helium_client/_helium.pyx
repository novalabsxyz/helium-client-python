# cython: cdivision = True
# cython: boundscheck = False
# cython: wraparound = False
# cython: profile = False
# cython: embedsignature = True

from collections import namedtuple
from libc.string cimport strerror, strlen, memcpy
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


def _check_status(status, builder=None, message=None):
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

    def reset(self):
        """Reset the Helium Atom."""
        cdef int status = reset(&self._ctx)
        return _check_status(status)

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
        return _check_status(status, lambda: Info(**info))

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
        return _check_status(connect(&self._ctx, NULL, retries))

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
        return _check_status(sleep(&self._ctx, NULL))

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

    def __enter__(self):
        return self

    def __exit__(self, a, b, tb):
        self.close()
        return True


cdef class Channel(object):
    """Send and receive data to IoT back-end channels.

    A channel can be created by calling :meth:`.Channel.create` or
    using the convenience method :meth:`.Helium.create_channel`.

    :ivar name: The name of the channel
    :ivar id: The id of the channel
    """

    cdef Helium _helium
    cdef public bytes name 
    cdef public int8_t id 
    
    def __cinit__(self, Helium helium, channel_id, channel_name=None):
        self._helium = helium
        self.id = channel_id
        self.name = channel_name

    @classmethod
    def create(cls, Helium helium, channel_name, retries=POLL_RETRIES_5S):
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

            A :class:`.Channel` instance if successful. If
            an error occurred or the number of retries is exhausted a
            :class:`.HeliumError` is raised.

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred

        """
        cdef uint16_t token
        cdef int status = channel_create(&helium._ctx, channel_name, len(channel_name), &token)
        channel_id = cls._poll_result(helium, status, token, cls._poll_result_func, retries=retries)
        return cls(helium, channel_id, channel_name=channel_name)

    def send(self, data, retries=POLL_RETRIES_5S):
        """Send data on a channel.

        Sends data on a Helium Channel and waits for a given number of
        retries for a response from the channel.

        Args:

            data (:obj:`bytes`): Data to send to the channel.

            retries (:obj:`int`, optional): The number of times to retry
                waiting for a response (defaults to about 5 seconds)

        """
        cdef uint16_t token
        cdef char * data_bytes = data
        cdef int status = channel_send(&self._helium._ctx, self.id,
                                       data_bytes, len(data), &token)
        self._poll_result(self._helium, status, token, self._poll_result_func, retries=retries)

    def poll_result(self, token, retries=POLL_RETRIES_5S):
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
        return self._poll_result(OK, token, retries=retries)

    def config(self):
        """Get the :class:`.Config` for this channel."""
        return Config(self, self._helium)

    @staticmethod
    def _poll_result_func(Helium helium, status, token, retries=POLL_RETRIES_5S):
        cdef int8_t result = 0
        if status == OK:
            status = channel_poll_result(&helium._ctx, token, &result, retries)
        return status, result, result

    @staticmethod
    def _poll_result(Helium helium, status, token, poll_func, retries=POLL_RETRIES_5S):
        status, result, value = poll_func(helium, status, token, retries=retries)

        def _check_status_details():
            if result >= 0:
                return value
            else:
                raise ChannelError(result)

        return _check_status(status, _check_status_details)

    def __repr__(self):
        return '{0} <name: {1} id: {2}>'.format(self.__class__.__name__,
                                                repr(self.name),
                                                self.channel_id)


cdef class Config(object):
    """Get and set global and channel specific configuration data.

    Helium supports configuration variables for a given device in two
    forms:

    * Global configuration variables - Variables that are available in
      every channel a device connects to. Global configuration
      variables can be fetched and updated using the ``config``
      prefix.

    * Channel configuration variables - Variables that are channel
      specific, only available if the channel supports it, and tied to
      the lifetime of the channel. Use the ``channel`` prefix when
      getting and setting channel configuration variables.

      Channel configuration variables are mapped to the equivalent
      constructs on the target platform if available. On Azure, for
      example, a ``get`` is mapped to the ``desired`` state of the
      device twin, where as a ``set`` updates the ``reported`` section
      of the device twin.
 
    Note:

        Not all channels support the same constructs or both get and
        set. Refer to the channel specific settings and documentation
        to see how much of the configuration API is supported.

    Example:
    
        To get a global configuration variable called ``interval``::
    
            config = channel.config()
            value = config.get("config.interval")

        To get a channel specific configuration variable called
        ``color``::

            config = channel.config()
            value = config.get("channel.color")
    
    """

    cdef Helium _helium
    cdef Channel _channel

    def __cinit__(self, Channel channel, Helium helium):
        self._channel = channel
        self._helium = helium

    def get(self, config_key, default=None, retries=POLL_RETRIES_5S):
        """Get a configuration variable.

        Fetches the configuration value for a given key.

        Args:

            config_key (:obj:`str`): The key to look up.
        
            retries (:obj:`int`, optional): The number of times to
                retry waiting for a response (defaults to about 5
                seconds)

        Keword Args:

            default: The default value to return if the key was not found.

        Returns:

            The value for the given key if found, the specified
            default if not found.

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred

        """
        cdef uint16_t token
        cdef int8_t result
        cdef int status = channel_config_get(&self._helium._ctx, self._channel.id,
                                             config_key, &token)
        response = self._channel._poll_result(self._helium, status, token, self._poll_get_result_func,
                                              retries=retries)
        return response.get(config_key, default)

    def set(self, config_key, config_value, retries=POLL_RETRIES_5S):
        """Set a configuration variable.

        Sets a configuration variable for the given key to the given
        value.

        Args:

            config_key (:obj:`str`): The key to look up.

            config_value: The value to set.
        
            retries (:obj:`int`, optional): The number of times to
                retry waiting for a response (defaults to about 5
                seconds)

        Raises:

            :class:`.HeliumError`: A HeliumError or subclass
                representing the error that occurred
        
        """
        cdef uint16_t token
        cdef int8_t result
        # Get the value copied into a buffer
        cdef int8_t value_data[100]
        self._value_config_value(config_value, <void *>value_data)
        # And send it up
        cdef int status = channel_config_set(&self._helium._ctx, self._channel.id,
                                             config_key, self._value_config_type(config_value),
                                             <void*>value_data, &token)
        self._channel._poll_result(self._helium, status, token, self._poll_set_result_func,
                                   retries=retries)

    def poll_invalidate(self, retries=POLL_RETRIES_5S):
        """Check for configuration invalidation.

        When a global or channel configuration variable is changed in
        the Dashboard or in the channel specific UI or API, an
        invalidation message is queued up for the device. 

        The invalidation message is delivered to the device as soon as
        the network detects the device transmitting data of any kind.

        This means that if you're sending data regularly already you
        can set ``retries`` to 0 to avoid another network round-trip.

        Args:

            retries (:obj:`int`, optional): The number of times to
                retry waiting for a response (defaults to about 5
                seconds)

        Returns:

            True if the global or channel specific configuration is
            invalid, False otherwise.

        Raises:

            A :class:`HeliumError` can be raised on errors. The
            :class:`NoDataError` error is intercepted and interpreted
            as if the configuration is not invalid.

        """
        cdef bool stale = False
        cdef int status = channel_config_poll_invalidate(&self._helium._ctx, self._channel.id,
                                                         &stale, retries)
        try:
            return _check_status(status, lambda: stale)
        except NoDataError:
            return False

    cdef helium_config_type _value_config_type(self, obj):
        if obj == None:
            return NIL
        elif type(obj) == int:
            return I32
        elif type(obj) == float:
            return F32
        elif type(obj) == type(True):
            return BOOL
        elif type(obj) == str:
            return STR
        else:
            raise ValueError("Values must be a string, int, float, bool or None")

    cdef void _value_config_value(self, obj, void *value):
        if obj == None:
            return
        elif type(obj) == int:
            (<int*>value)[0] = obj;
        elif type(obj) == float:
            (<float*>value)[0] = obj;
        elif type(obj) == type(True):
            (<bool*>value)[0] = obj;
        elif type(obj) == str:
            memcpy(value, <char*>obj, strlen(<char*>obj))
        else:
            raise ValueError("Values must be a string, int, float, bool or None")

    @staticmethod
    def _poll_get_result_func(Helium helium, status, token, retries=POLL_RETRIES_5S):
        cdef int8_t result = 0
        handler_ctx = {}
        if status == OK:
            status = channel_config_get_poll_result(&helium._ctx, token, _config_get_handler,
                                                    <void *>handler_ctx, &result, retries)
        return status, result, handler_ctx

    @staticmethod
    def _poll_set_result_func(Helium helium, status, token, retries=POLL_RETRIES_5S):
        cdef int8_t result = 0
        if status == OK:
            status = channel_config_set_poll_result(&helium._ctx, token, &result, retries)
        return status, result, result


    def __repr__(self):
        return '{0} <channel: {1}>'.format(self.__class__.__name__,
                                           repr(self._channel.name))


cdef bool _config_get_handler(void *ctx, const char *config_key,
                              helium_config_type config_type, void *value):
    config = <object>ctx
    if config_type == I32:
        config_value = (<int*>value)[0]
    elif config_type == F32:
        config_value = (<float*>value)[0]
    elif config_type == BOOL:
        config_value = (<bool*>value)[0]
    elif config_type == STR:
        config_value = <bytes><char *>value
    elif config_type == NIL:
        config_value = None

    if config_value is not None:
        config[config_key] = config_value
    return False


