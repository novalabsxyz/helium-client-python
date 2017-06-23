cimport chelium_client as chelium
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
    __slots__ = ()

    def __repr__(self):
        return "Helium <mac: {:08x} version: {:04x}>".format(self.mac, self.fw_version)

class HeliumError(Exception):
    pass

class NoDataError(HeliumError):
    pass

class CommunicationError(HeliumError):
    pass

class NotConnectedError(HeliumError):
    pass

class DroppedError(HeliumError):
    pass

class KeepAwakeError(HeliumError):
    pass

class ChannelError(HeliumError):
    pass

error_classes = {
    chelium.OK_NO_DATA:            NoDataError,
    chelium.ERR_DROPPED:            DroppedError,
    chelium.ERR_COMMUNICATION:  CommunicationError,
    chelium.ERR_NOT_CONNECTED:  NotConnectedError,
    chelium.ERR_KEEP_AWAKE:         KeepAwakeError
}


def _error_for(status, message=None):
    klazz = error_classes.get(status, None)
    if klazz is None:
        klazz = HeliumError
    return klazz(message or status)


def _check_result(self, status, builder=None, message=None):
    if status == chelium.OK:
        return None if builder is None else builder()
    raise _error_for(status, message)


cdef class Helium:

    cdef chelium.ctx _ctx

    def __cinit__(self, const char * device_file):
        self._ctx.param = <void *><intptr_t>0
        fd = chelium.open_serial_port(device_file, chelium.baud_9600)
        if fd < 0:
            raise CommunicationError(strerror(errno))
        chelium.init(&self._ctx, <void *><intptr_t>fd)

    def needs_reset(self):
        return chelium.needs_reset(&self._ctx)

    def info(self):
        cdef chelium.info info
        cdef int status = chelium._info(&self._ctx, &info)
        return _check_result(self, status, lambda: Info(**info))

    def connect(self, retries=chelium.POLL_RETRIES_5S):
        return _check_result(self, chelium.connect(&self._ctx, NULL, retries))

    def connected(self):
        return chelium.connected(&self._ctx)

    def sleep(self):
        return _check_result(self, chelium.sleep(&self._ctx, NULL))

    def close(self):
        cdef int fd = <int>self._ctx.param
        if fd != 0:
            chelium.close_serial_port(fd)

    def create_channel(self, channel_name, retries=chelium.POLL_RETRIES_5S):
        return Channel.create(self, channel_name, retries=retries)

    def _channel_response(self, status, token, retries=chelium.POLL_RETRIES_5S):
        if retries is None:
            return _check_result(self, status, lambda: token)

        cdef int8_t result
        if status == chelium.OK:
            status = chelium.channel_poll_result(&self._ctx, token, &result, retries)

        def _check_result_details():
            if result >= 0:
                return result
            else:
                raise ChannelError(result)

        return _check_result(self, status, _check_result_details)

    def _channel_create(self, channel_name, retries=chelium.POLL_RETRIES_5S):
        cdef uint16_t token
        cdef int status = chelium.channel_create(&self._ctx, channel_name, len(channel_name), &token)
        return self._channel_response(status, token, retries=retries)

    def _channel_send(self, channel_id, data, retries=chelium.POLL_RETRIES_5S):
        cdef uint16_t token
        cdef char * data_bytes = data
        cdef int status = chelium.channel_send(&self._ctx, channel_id, data_bytes, len(data), &token)
        return self._channel_response(status, token, retries=retries)

    def __enter__(self):
        return self

    def __exit__(self, a, b, tb):
        self.close()
        return True


class Channel(object):

    def __init__(self, helium, channel_id, channel_name=None):
        self._helium = helium
        self._channel_id = channel_id
        self._channel_name = channel_name

    @classmethod
    def create(cls, helium, channel_name, retries=chelium.POLL_RETRIES_5S):
        channel_id = helium._channel_create(channel_name, retries=retries)
        return cls(helium, channel_id, channel_name=channel_name)

    def send(self, data, retries=chelium.POLL_RETRIES_5S):
        self._helium._channel_send(self._channel_id, data, retries=retries)

    def __repr__(self):
        return '{0} <name: {1} id: {2}>'.format(self.__class__.__name__, repr(self._channel_name), self._channel_id)
