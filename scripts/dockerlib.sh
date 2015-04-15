#!/bin/bash

# Author Gabriel Hartmann <gabhart@microsoft.com>
#-------------------------------------------------------------------------
# Copyright (c) Microsoft Open Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------

DISTRO=$(awk -F'=' '{if($1=="DISTRIB_ID")print $2; }' /etc/*-release)

if [ $DISTRO == "CoreOS" ]; then
    type python >/dev/null 2>&1 || { export PATH=$PATH:/usr/share/oem/python/bin/; }
    type python >/dev/null 2>&1 || { echo >&2 "Python is required but it's not installed."; exit 1; }
fi

json_val() {
    python -c 'import json,sys;obj=json.load(sys.stdin);print obj'$1'';
}

json_dump() {
    python -c 'import json,sys;obj=json.load(sys.stdin);print json.dumps(obj'$1')';
}

yaml_dump() {
    python -c 'import json,yaml,sys;data=json.load(sys.stdin);print yaml.safe_dump(data, default_flow_style=False)'
}

SCRIPT_DIR=$(cd $(dirname $0); pwd)
LOG_DIR=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | json_val '[0]["handlerEnvironment"]["logFolder"]')
CONFIG_DIR=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | json_val '[0]["handlerEnvironment"]["configFolder"]')
STATUS_DIR=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | json_val '[0]["handlerEnvironment"]["statusFolder"]')

LOG_FILE=$LOG_DIR/docker-handler.log
CONFIG_FILE=$(ls $CONFIG_DIR | grep -E ^[0-9]+.settings$ | sort -n | tail -n 1)
STATUS_FILE=$(echo $CONFIG_FILE | sed s/settings/status/)

log() {
    local file_name=${0##*/}
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp $file_name: $1"
}

validate_distro() {
    if [ $DISTRO == "" ]; then
	log "Error reading DISTRO"
	exit 1
    fi

    if [[ $DISTRO == "CoreOS" || $DISTRO == "Ubuntu" ]]; then
	log "OS $DISTRO is supported."
    else
	log "OS $DISTRO is NOT supported."
	exit 1;
    fi
}
