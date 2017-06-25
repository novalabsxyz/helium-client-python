.. helium-client-python documentation master file, created by
   sphinx-quickstart on Fri Jun 23 16:24:33 2017.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Overview
====================

helium-client-python is a wrapper around the `helium-client
<https://github.com/helium/helium-client>`_ library. It provides an
easy to use Python API to the `Helium Atom
<https://www.helium.com/products/atom-xbee-module>`_ wireless module
that makes it easy to connect a device to a number back-end services.


Installation
--------------------

This library will need to compile some native extensions in order to
do its work. In order to do so you will need a working compiler on
your system and may need to install the ``python-dev`` package, or the
equivalent package that allows native Python extension development for
your platform.

On Raspberry Pi for example:

.. code-block:: shell-session

   apt-get install python-dev


Check out the source from the git repository and install using `pip`:

.. code-block:: shell-session

   git clone https://github.com/helium/helium-client-python
   cd helium-client-python
   pip install .


Usage
--------------------

Once installed the use of library will require access to the serial
port that the Helium Atom is connected to.

On Raspberry Pi, for example, the serial port is ``/dev/serial1``.

.. note::

   Ensure that the user that will be running the Python code has
   access to the serial port the Helium Atom is connected to, and that
   the operating system is not using the serial port for other
   reasons.

Once that is completed you should be able to run the following Python
script:

.. code-block:: python

   from helium_client import Helium

   # enter the right serial port here
   helium = Helium('/dev/serial1')
   helium.connect()

After which you should see the Helium Atom blink it's blue and red
LEDs as it tries to connect to the Helium Element.

Once you have configured a Channel in the Helium Dashboard you can
send data to that channel using something similar to the following:


.. code-block:: python

   # enter right channel here
   channel = helium.create_channel('Helium MQTT Channel')
   channel.send("Hello Helium!")

Please see the Reference section for limitations and potential raised
errors for the various methods.


.. toctree::
   :maxdepth: 2
   :caption: Contents:

   Reference <reference>
