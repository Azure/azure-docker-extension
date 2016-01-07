#!/bin/bash
set -eu
readonly SCRIPT_DIR=$(dirname $0)

# This script kicks off the ./bin/docker-extension in the
# background and disowns it with nohup. This is a workaround
# for the 5-minute time limit for 'enable' step and 15-minute
# time limit for 'install' step of the Windows Azure VM Extension
# model which exists by design. By forking and running in the 
# background, the process does not get killed after the timeout
# and yet still reports its progress through '.status' files to
# the extension system.

# First, report "transitioning" status through .status file before
# returning from this script so that agent can see the file before
# the main extension executable starts. Another workaround really.

# status_file returns the .status file path we are supposed to write
# by determining the highest sequence number from .settings files.
status_file_path() {
        # normally we'd need to find this config_dir by parsing the
        # HandlerEnvironment.json, but hey we're in a bash script here,
        # so assume it's at ../config/.
        local config_dir=$(readlink -f "${SCRIPT_DIR}/../config")
        local status_dir=$(readlink -f "${SCRIPT_DIR}/../status")
        config_file=$(ls $config_dir | grep -E ^[0-9]+.settings$ | sort -n | tail -n 1)
        status_file=$(echo $config_file | sed s/settings/status/)
        readlink -f "$status_dir/$status_file"
}

write_status() {
	local timestamp="$(date --utc --iso-8601=seconds)"
	local status_file=$(status_file_path)
	echo "Writing status to $status_file."
	cat > "$status_file" <<- EOF
		[
			{
				"version": 1,
				"timestampUTC": "$timestamp",
				"status": {
					"operation": "Enable Docker",
					"status": "transitioning",
					"formattedMessage": {
						"lang": "en",
						"message": "Enabling Docker"
					}
				}
			}
		]
	EOF
}


write_status
set -x
nohup $(readlink -f "$SCRIPT_DIR/../bin/docker-extension") $@ > /var/log/nohup.log &
