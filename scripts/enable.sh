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

distrib_id=$(awk -F'=' '{if($1=="DISTRIB_ID")print $2; }' /etc/*-release);

if [ $distrib_id == "" ]; then
    echo "Error reading DISTRIB_ID"
    exit 1
elif [ $distrib_id == "Ubuntu" ]; then
    echo "This is Ubuntu."
elif [ $distrib_id == "CoreOS" ]; then
    echo "This is CoreOS."
    type python >/dev/null 2>&1 || { export PATH=$PATH:/usr/share/oem/python/bin/; }
    type python >/dev/null 2>&1 || { echo >&2 "Python is required but it's not installed."; exit 1; }
else
    echo "Unsupported Linux distribution."
    exit 1
fi

function json_val () {
    python -c 'import json,sys;obj=json.load(sys.stdin);print obj'$1'';
}

logdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["logFolder"]')
logfile=$logdir/docker-handler.log

exec >> $logfile 2>&1

echo "Enabling Docker"

configdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["configFolder"]')
configfile=$(ls $configdir | grep -E ^[0-9]+.settings$ | sort -n | tail -n 1)
config=$configdir/$configfile
echo Using config: $config

statusfile=$(echo $configfile | sed s/settings/status/)
statusdir=$(cat $SCRIPT_DIR/../HandlerEnvironment.json | \
    json_val '[0]["handlerEnvironment"]["statusFolder"]')
status=$statusdir/$statusfile

cat $SCRIPT_DIR/running.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status

if [ -n "$(cat $config | json_val \
    '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["installonly"]' \
    2>/dev/null )" ]; then
    install_only=$(cat $config | json_val \
    '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["installonly"]')
else
    install_only="false"
fi

if [ $install_only == "true" ]; then
    cat $SCRIPT_DIR/success.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status
    exit
fi

docker_dir=/etc/docker

if [ ! -d $docker_dir ]; then
    echo "Creating $docker_dir"
    mkdir $docker_dir
fi

thumb=$(cat $config | json_val \
    '["runtimeSettings"][0]["handlerSettings"]["protectedSettingsCertThumbprint"]')
cert=/var/lib/waagent/${thumb}.crt
pkey=/var/lib/waagent/${thumb}.prv
prot=$SCRIPT_DIR/prot.json

cat $config | \
    json_val '["runtimeSettings"][0]["handlerSettings"]["protectedSettings"]' | \
    base64 -d | \
    openssl smime  -inform DER -decrypt -recip $cert  -inkey $pkey > \
    $prot

secure="false"
if [ -n "$(cat $prot | json_val '["ca"]' 2>/dev/null)" ]; then
    echo "Creating Certs"
    secure="true"
    cat $prot | json_val '["ca"]' | base64 -d > $docker_dir/ca.pem
    cat $prot | json_val '["server-cert"]' | base64 -d > $docker_dir/server-cert.pem
    cat $prot | json_val '["server-key"]' | base64 -d > $docker_dir/server-key.pem
    rm $prot
    chmod 600 $docker_dir/*
fi

port=$(cat $config | json_val \
    '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["dockerport"]')

echo Docker port: $port

if [ $distrib_id == "Ubuntu" ]; then
    echo "Setting up /etc/default/docker"
    if [ $secure == "true" ]; then
        cat <<EOF > /etc/default/docker
DOCKER_OPTS="--tlsverify --tlscacert=$docker_dir/ca.pem --tlscert=$docker_dir/server-cert.pem --tlskey=$docker_dir/server-key.pem -H=0.0.0.0:$port"
EOF
    else
        cat <<EOF > /etc/default/docker
DOCKER_OPTS="-H=0.0.0.0:$port"
EOF
    fi

    echo "Starting Docker"
    update-rc.d docker defaults
    service docker restart
elif [ $distrib_id == "CoreOS" ]; then
    if [ $secure == "true" ]; then
        sed -i "s%ExecStart=.*%ExecStart=/usr/bin/docker --daemon --tlsverify --tlscacert=$docker_dir/ca.pem --tlscert=$docker_dir/server-cert.pem --tlskey=$docker_dir/server-key.pem -H=0.0.0.0:$port%" /etc/systemd/system/docker.service
    else
        sed -i "s%ExecStart=.*%ExecStart=/usr/bin/docker --daemon -H=0.0.0.0:$port%" /etc/systemd/system/docker.service
    fi

    systemctl daemon-reload
    systemctl restart docker
else
    echo "Unsupported Linux distribution."
    exit 1
fi

cat $SCRIPT_DIR/success.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status
