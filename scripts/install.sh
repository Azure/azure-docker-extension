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
status=$STATUS_DIR/$STATUS_FILE

cat $SCRIPT_DIR/running.status.json | sed s/@@DATE@@/$(date -u +%FT%TZ)/ > $status

log "Installing Docker..."

if [ $DISTRO == "Ubuntu" ]; then
    wget -qO- https://get.docker.com/ | sh
elif [ $DISTRO == "CoreOS" ]; then
    log "Copy /usr/lib/systemd/system/docker.service --> /etc/systemd/system/"
    cp /usr/lib/systemd/system/docker.service /etc/systemd/system/
fi

log "Add user to docker group"
azureuser=$(grep -Eo '<UserName>.+</UserName>' /var/lib/waagent/ovf-env.xml | awk -F'[<>]' '{ print $3 }')
sed -i -r "s/^docker:x:[0-9]+:$/&$azureuser/" /etc/group

log "Done installing Docker"

log "Installing Docker Compose..."

if [ $DISTRO == "CoreOS" ]; then
    COMPOSE_DIR=/opt/bin
    mkdir -p $compose_dir
else
    COMPOSE_DIR=/usr/local/bin
fi

curl -L https://github.com/docker/compose/releases/download/1.2.0/docker-compose-`uname -s`-`uname -m` > $COMPOSE_DIR/docker-compose
chmod +x $COMPOSE_DIR/docker-compose

log "Done installing Docker Compose"
