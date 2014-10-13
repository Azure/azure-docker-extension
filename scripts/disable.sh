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

set -e

distrib_id=$(awk -F'=' '{if($1=="DISTRIB_ID")print $2; }' /etc/*-release);

if [ $distrib_id == "" ]; then
	echo "Error reading DISTRIB_ID"
	exit 1
elif [ $distrib_id == "Ubuntu" ]; then
	echo "This is Ubuntu."
    service docker.io stop
    #update-rc.d docker.io off ?
elif [ $distrib_id == "CoreOS" ]; then
	echo "This is CoreOS."
	systemctl stop docker
else
	echo "Unsupported Linux distribution."
	exit 1
fi
