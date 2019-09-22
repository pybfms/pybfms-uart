#!/bin/sh

etc_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd)"
UART_BFMS=`cd $etc_dir/.. ; pwd`
export UART_BFMS

# Add a path to the simscripts directory
export PATH=$UART_BFMS/packages/simscripts/bin:$PATH

# Force the PACKAGES_DIR
export PACKAGES_DIR=$UART_BFMS/packages

