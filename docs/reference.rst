Reference
====================


Helium
--------------------

.. autoclass:: helium_client.Helium
   :members:

Info
~~~~~~~~~~~~~~~~~~~~

.. autoclass:: helium_client.Info


Channel
--------------------

.. autoclass:: helium_client.Channel
   :members:

Config
--------------------

.. autoclass:: helium_client.Config
   :members:


Errors
--------------------

.. autoclass:: helium_client.HeliumError

.. autoclass:: helium_client.NoDataError

.. autoclass:: helium_client.CommunicationError

.. autoclass:: helium_client.NotConnectedError

.. autoclass:: helium_client.DroppedError

.. autoclass:: helium_client.KeepAwakeError

.. autoclass:: helium_client.ChannelError



Constants
--------------------

.. data:: POLL_RETRIES_5S

   The number of retries that is about 5 seconds to poll the Helium Atom for.

   When making requests to the :class:`.Helium` and :class:`.Channel`
   objects they are sent over the serial port to the Helium Atom. In
   order to not wait indefinitely for a response you can specify how
   many times to poll the Atom for a response and have sleep for a
   small amount of time between each request.

   This constant represents approximately 5 seconds of wait time. It
   is not intended to be a precise timeout but helps detect requests
   that have run too long.
