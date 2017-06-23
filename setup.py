#!/usr/bin/env python

"""
setup.py file for helium-client-python
"""

from distutils.core import setup, Extension

sourcefiles = ['src/helium_client.c',
               'src/helium_serial.c',
               'src/helium-client/helium-client.c',
               'src/helium-client/cauterize/atom_api.c',
               'src/helium-client/cauterize/atom_api_message.c',
               'src/helium-client/cauterize/cauterize.c']

extensions = [Extension('helium_client',
                        include_dirs=['src/helium-client'],
			extra_compile_args=['-std=gnu99'],
                        sources=sourcefiles)]

setup(name='helium-client',
      version='0.1',
      author="Helium Client",
      description="""Python interface to the Helium Atom""",
      ext_modules=extensions)
