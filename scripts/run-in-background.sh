#!/bin/bash
set -eu

# This script kicks off the ./bin/docker-extension in the
# background and disowns it with nohup. This is a workaround
# for the 5-minute time limit for 'enable' step and 15-minute
# time limit for 'install' step of the Windows Azure VM Extension
# model which exists by design. By forking and running in the 
# background, the process does not get killed after the timeout
# and yet still reports its progress through '.status' files to
# the extension system.

nohup ./bin/docker-extension $@ > /var/log/nohup.log &
