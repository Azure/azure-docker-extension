#!/bin/bash

# Author Jeff Mendoza <jeffmendoza@live.com>
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

set -eu
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd $(dirname $0); pwd)

function json_val () { 
    python -c 'import json,sys;obj=json.load(sys.stdin);print obj'$1''; 
}

logdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["logFolder"]')
#    json_val '["handlerEnvironment"]["logFolder"]')
logfile=$logdir/docker-handler.log

exec >> $logfile 2>&1

configdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["configFolder"]')
#    json_val '["handlerEnvironment"]["configFolder"]')
configfile=$(ls $configdir | grep -P ^[0-9]+.settings$ | sort -n | tail -n 1)

statusfile=$(echo $configfile | sed s/settings/status/)
statusdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["statusFolder"]')
#    json_val '["handlerEnvironment"]["statusFolder"]')
status=$statusdir/$statusfile

cat $SCRIPT_DIR/running.status.json | sed s/@@DATE@@/$(date -u -Ins)/ > $status


echo "Installing Docker"

apt-get update
apt-get install -y docker.io
wget https://get.docker.io/builds/Linux/x86_64/docker-latest.tgz
tar -xzvf docker-latest.tgz -C /
rm docker-latest.tgz

echo "Done Installing Docker"
