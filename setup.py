#!/usr/bin/env python


from distutils.core import setup

setup(
	name='uart_bfms',
	version='0.0.1',
	description="UART BFMS",
  	license = "Apache 2.0",
	author='Matthew Ballance',
	author_email='matt.ballance@gmail.com',
  	packages=['uart_bfms'],
	package_dir = {'' : 'src'},
	url='http://github.com/sv-bfms/uart_bfms',
	data_files=[('rtl', ['rtl/*'])]
)



