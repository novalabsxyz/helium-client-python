#!/usr/bin/env python

"""
setup.py file for helium-client-python
"""

from setuptools import setup, find_packages
from setuptools.extension import Extension
from setuptools.command.build_ext import build_ext
import codecs
import versioneer

def get_ext_modules():
    local_inc = 'helium_client/helium-client'
    local_sources = ['helium_client/_helium.c',
                     'helium_client/_serial.c',
                     'helium_client/helium-client/helium-client.c',
                     'helium_client/helium-client/cauterize/atom_api.c',
                     'helium_client/helium-client/cauterize/atom_api_message.c',
                     'helium_client/helium-client/cauterize/cauterize.c']
    extra_compile_args = ['-std=gnu99', '-Werror']

    return [
        Extension(name="helium_client._helium",
                  sources=local_sources,
                  include_dirs=[local_inc],
                  extra_compile_args=extra_compile_args),
    ]

cmdclass = {'build_ext' : build_ext}
cmdclass.update(versioneer.get_cmdclass())

setup(
    name='helium_client',
    version=versioneer.get_version(),
    author='Helium',
    author_email='info@helium.com',
    packages=find_packages(),
    license='LICENSE.txt',
    url="http://github.com/helium/helium-client-python",
    description='A Python interface to the Helium Atom.',
    long_description=codecs.open('README.md',
                                 mode='r', encoding='utf-8').read(),
    classifiers=['Intended Audience :: Developers',
                 'License :: OSI Approved :: BSD License',
                 'Development Status :: 3 - Alpha',
                 'Operating System :: MacOS',
                 'Operating System :: Microsoft :: Windows',
                 'Operating System :: POSIX',
                 'Operating System :: Unix',
                 'Programming Language :: Cython',
                 'Programming Language :: Python',
                 'Programming Language :: Python :: 2',
                 'Programming Language :: Python :: 2.7',
                 'Programming Language :: Python :: 3',
                 'Programming Language :: Python :: 3.5',
                 'Topic :: Software Development'],
    extras_require={'dev':  ['cython']},
    include_package_data=True,
    ext_modules=get_ext_modules(),
    cmdclass=cmdclass,
)
