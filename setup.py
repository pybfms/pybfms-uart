#!/usr/bin/env python

import os

import sys, os.path, platform, warnings

from distutils import log
from distutils.core import setup, Command

VERSION = None
with open("etc/ivpm.info") as fp:
  for line in fp:
    if line.find("version=") != -1:
      VERSION = line[line.find("=")+1:].strip()
      break

if VERSION is None:
  print("Error: null version")

if "BUILD_NUM" in os.environ:
  VERSION += "." + os.environ["BUILD_NUM"]

try:
    from wheel.bdist_wheel import bdist_wheel
except ImportError:
    bdist_wheel = None

cmdclass = {
}
if bdist_wheel:
    cmdclass['bdist_wheel'] = bdist_wheel

setup(
  name = "pybfms-uart",
  version=VERSION,
  packages=['uart_bfms'],
  package_dir = {'' : 'src'},
  package_data = {'uart_bfms': [
      'share/hdl/*.v',
      'share/sw/c/*.h',
      'share/sw/c/*.c',
      ]},
  author = "Matthew Ballance",
  author_email = "matt.ballance@gmail.com",
  description = ("pybfms-uart provides bus functional models for UART protocol"),
  license = "Apache 2.0",
  keywords = ["SystemVerilog", "Verilog", "RTL", "cocotb"],
  url = "https://github.com/pybfms/pybfms-uart",
  setup_requires=[
    'setuptools_scm',
  ],
  cmdclass=cmdclass,
  install_requires=[
    'cocotb',
    'pybfms',
  ],
)




