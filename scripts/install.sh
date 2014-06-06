#!/bin/bash

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
