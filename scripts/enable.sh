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
source ./dockerlib.sh

validate_distro

IFS=$'\n\t'

exec >> $LOG_FILE 2>&1

log "Enabling Docker"

config=$CONFIG_DIR/$CONFIG_FILE
log "Using config: $config"

status=$STATUS_DIR/$STATUS_FILE

cat $SCRIPT_DIR/running.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status

azureuser=$(grep -Eo '<UserName>.+</UserName>' /var/lib/waagent/ovf-env.xml | awk -F'[<>]' '{ print $3 }')

if [ -n "$(cat $config | json_dump '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["composeup"]' 2>/dev/null )" ]; then
    compose_up=$(cat $config | json_dump '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["composeup"]')
else
    compose_up="false"
fi

if [ "$compose_up" != "false" ]; then
    log "composing:"
    echo $compose_up | yaml_dump
    mkdir -p "/home/$azureuser/compose"
    pushd "/home/$azureuser/compose"
    echo $compose_up | yaml_dump > ./docker-compose.yml
    docker-compose up -d
    popd
else
    log "No compose args, not starting anything"
fi

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
    log "Creating $docker_dir"
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

log "Creating Certs"
cat $prot | json_val '["ca"]' | base64 -d > $docker_dir/ca.pem
cat $prot | json_val '["server-cert"]' | base64 -d > $docker_dir/server-cert.pem
cat $prot | json_val '["server-key"]' | base64 -d > $docker_dir/server-key.pem
rm $prot
chmod 600 $docker_dir/*

port=$(cat $config | json_val \
    '["runtimeSettings"][0]["handlerSettings"]["publicSettings"]["dockerport"]')

log "Docker port: $port"

if [ $DISTRO == "Ubuntu" ]; then
    log "Setting up /etc/default/docker"
    cat <<EOF > /etc/default/docker
DOCKER_OPTS="--tlsverify --tlscacert=$docker_dir/ca.pem --tlscert=$docker_dir/server-cert.pem --tlskey=$docker_dir/server-key.pem -H=0.0.0.0:$port"
EOF

    log "Starting Docker"
    update-rc.d docker defaults
    service docker restart
elif [ $DISTRO == "CoreOS" ]; then
    sed -i "s%ExecStart=.*%ExecStart=/usr/bin/docker --daemon --tlsverify --tlscacert=$docker_dir/ca.pem --tlscert=$docker_dir/server-cert.pem --tlskey=$docker_dir/server-key.pem -H=0.0.0.0:$port%" /etc/systemd/system/docker.service

    systemctl daemon-reload
    systemctl restart docker
fi

cat $SCRIPT_DIR/success.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status
