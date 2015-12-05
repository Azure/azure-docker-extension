#!/bin/bash
set -eou pipefail
IFS=$'\n\t'

# these flighting values should match Makefile
readonly TEST_SUBS="c3dfd792-49a4-4b06-80fc-6fc6d06c4742"
readonly TEST_REGION="Brazil South"

# supported images (add/update them as new major versions come out)
readonly DISTROS=(
	"2b171e93f07c4903bcad35bda10acf22__CoreOS-Beta-877.1.0" \
	"5112500ae3b842c8b9c604889f8753c3__OpenLogic-CentOS-71-20150731" \
	"b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-14_04_3-LTS-amd64-server-20151117-en-us-30GB" \
	"b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-15_04-amd64-server-20151201-en-us-30GB" \

)

# Test constants
readonly SCRIPT_DIR=$(dirname $0)
readonly DOCKER_CERTS_DIR=dockercerts
readonly VM_PREFIX=dockerexttest-
readonly VM_USER=azureuser
readonly EXTENSION_NAME=DockerExtension
readonly EXTENSION_PUBLISHER=Microsoft.Azure.Extensions
readonly EXTENSION_VERSION=1.0
readonly EXTENSION_CONFIG=extensionconfig/public.json
readonly EXTENSION_CONFIG_PROT=extensionconfig/protected.json
expected_extension_version=


### Functions

log() {
	echo "[$(date +%T)][DEBUG]" "$@"
}

err() {
	echo >&2 "[$(date +%T)][ERROR]" "$@"
}

is_empty() {
    local var=$1
    [[ -z $var ]]
}

is_file() {
    local file=$1
    [[ -f $file ]]
}


command_exists() {
	command -v "$@" > /dev/null 2>&1
}

check_deps() {
	local deps=(azure jq docker curl)

	local cmd=
	for cmd in "${deps[@]}"; do
		command_exists $cmd || { err "$cmd not installed."; exit 1; }
	done
}

check_asm() {
	# capture "Current Mode: arm" from azure cmd output
	if [[ "$(azure)" != *"Current Mode: asm"* ]]; then
		cat <<- EOF
		azure CLI not in ASM mode (required for testing). Run:

		  azure config mode asm
		
		NOTE: internal versions in PIR don't propogate to ARM stack until they're
		published to PROD globally, hence 'asm')
		EOF
		exit 1
	fi
}

intro() {
	cat <<- EOF
	$EXTENSION_NAME integration tests:

	Execution Plan
	==============
	1. Create Azure VMs in the first slice region (make sure 'make publish + make replicationstatus').
	2. Add VM extension with a config exercising features to the VMs.
	3. Make sure the correct version has landed to the VMs.
	4. Wait until the VMs reach the goal state provided by $EXTENSION_NAME. 
	5. Clean up VMs.


	EOF
}

set_subs() {
	log "Setting subscription to $TEST_SUBS..."
	azure account set $TEST_SUBS 1>/dev/null
}

ssh_key() {
	echo "$SCRIPT_DIR/id_rsa"
}

ssh_pub_key() {
	echo "$(ssh_key).pub"
}

generate_ssh_keys() {
	local key=$(ssh_key)
	local pub=$(ssh_pub_key)

	is_file "$key" && is_file "$pub" && {
		# no need to regenerate keys
		return
	}

	log "Generating SSH keys..."
	rm -f "$key" "$pub"
	(
		set -x
		ssh-keygen -q -f "$key" -N ""
	)
	log "SSH keys generated."
}

trim_publisher() {
	# trims before __ in image name to get rid of publisher GUID
	echo $1 | sed 's/.*__//g'
}

print_distros() {
	log "Distro images to be tested:"

	local d
	for d in "${DISTROS[@]}"; do
		log " - $(trim_publisher $d)"
	done
}

vm_name() {
	local i=$1
	echo "$VM_PREFIX$i"
}

vm_fqdn() {
	local name=$1
	echo "$name.cloudapp.net"	
}

create_vm() {
	local name=$1
	local img=$2
	local key=$(ssh_pub_key)

	log "Creating VM $name ($(trim_publisher $img))..."
	(
		set -x
		azure vm create $name $img \
		  -e 22 -l "$TEST_REGION" \
		  --no-ssh-password \
		  --ssh-cert "$key" \
		  $VM_USER 1>/dev/null

		azure vm endpoint create $name 80 80 1>/dev/null
		azure vm endpoint create $name 2376 2376 1>/dev/null
	)
	log "Created VM $name."
}

create_vms() {
	generate_ssh_keys
	print_distros
	
	local i=0
	for d in "${DISTROS[@]}"; do
		i=$(( i+1 ))
		create_vm "$(vm_name $i)" "$d"
	done
}

delete_vm() {
	local name=$1
	log "Deleting VM $name..."
	(
		set -x
		azure vm delete -b -q "$name" 1>/dev/null
	)
	log "Deleted VM $name."
}

get_vms() {
	local list_json=$(azure vm list --json)
	echo $list_json | jq -r '.[].VMName' | grep "^$VM_PREFIX" | sort -n
}

delete_vms() {
	log "Cleaning up test VMs..."
	local vms=$(get_vms)
	for vm in $vms; do
		delete_vm "$vm"
	done
}

add_extension_to_vm() {
	local name=$1	
	
	local pub_config="$SCRIPT_DIR/$EXTENSION_CONFIG"
	local prot_config="$SCRIPT_DIR/$EXTENSION_CONFIG_PROT"

	(
		set -x
		azure vm extension set $name \
			$EXTENSION_NAME $EXTENSION_PUBLISHER $EXTENSION_VERSION \
			--public-config-path  "$pub_config" \
			--private-config-path "$prot_config" 1>/dev/null
	)
}

add_extension_to_vms() {
	log "Adding extension to VMs..."
	local vms=$(get_vms)
	for vm in $vms; do
		add_extension_to_vm "$vm"
	done
}

docker_addr() {
	local fqdn=$1
	echo "tcp://$1:2376"
}

docker_cert_path() {
	echo "$SCRIPT_DIR/$DOCKER_CERTS_DIR"
}

wait_for_docker() {
	local host=$1
	local addr=$(docker_addr $host)

	local docker_certs="$(docker_cert_path)"

	# Validate "docker info" works
	local docker_env="DOCKER_CERT_PATH=\"$docker_certs\" DOCKER_HOST=\"$addr\""
	local docker_cmd="docker --tls info"
	log "Waiting for Docker engine on $addr..."
	echo "+ $docker_cmd"
	
	while true; do
		set +e # ignore errors b/c the following command will retry

		set +e
		eval $docker_env $docker_cmd 1>/dev/null 2>&1
		local exit_code=$?
		set -e

		if [ $exit_code -ne 0 ]; then
			printf '.'
			sleep 5
		else
			log "Authenticated to docker engine at $addr."
			# Check if docker.options in public.json took effect
			local docker_info_out="$(eval $docker_cmd 2>&1)"
			if [[ "$docker_info_out" != *"foo=bar"* ]]; then
				err "Docker engine label (foo=bar) specified in extension configuration did not take effect."
				log "docker info output:"
				log "$docker_info_out"
				exit 1
			fi
			log "Docker configuration took effect."
			return
		fi
	done
}

wait_for_container() {
	local host=$1
	local addr="http://$1:80/"

	log "Waiting for web container on $addr..."
	local curl_cmd="curl -sILfo/dev/null $addr"
	echo "+ $curl_cmd"
	
	while true; do
		set +e
		eval $curl_cmd 2>&1 1>/dev/null
		local exit_code=$?
		set -e

		if [ $exit_code -eq 0 ]; then
			log "Web container is up."
			return
		fi
		printf '.'
		sleep 5
	done
}

validate_extension_version() {
	local fqdn=$1
	log "Validating extension version on VM."
	
	# Search for file Microsoft.Azure.Extensions.DockerExtension-{version}
	local prefix="${EXTENSION_PUBLISHER}.${EXTENSION_NAME}-"

	# Find out what version of extension is installed by running
	# a Docker container with /var/lib/waagent mounted
	local docker_env="DOCKER_CERT_PATH=\"$(docker_cert_path)\" DOCKER_HOST=\"$(docker_addr $fqdn)\""
	local docker_cmd="docker --tls run --rm -i -v /var/lib/waagent:/agent busybox ls -1 /agent | grep '^$prefix'"

	echo "+ $docker_env $docker_cmd"
	local version="$(eval $docker_env $docker_cmd 2>/dev/null | sed "s/^$prefix//g")"
	is_empty "$version" && {
		err "Could not locate $EXTENSION_NAME version."
		exit 1
	}
	
	if [[ "$version" != "$expected_extension_ver" ]]; then
		err "Wrong $EXTENSION_NAME encountered: '$version' (expected: '$expected_extension_ver')."
		exit 1
	fi
	log "VM has the correct version of $EXTENSION_NAME."
}

validate_vm() {
	local name=$1
	local fqdn=$(vm_fqdn $name)

	log "Validating $EXTENSION_NAME on VM '$name'"
	wait_for_docker $fqdn
	wait_for_container $fqdn
	validate_extension_version $fqdn
}

validate_vms() {
	log "Validating VMs..."		
	local vms=$(get_vms)
	for vm in $vms; do
		validate_vm "$vm"
	done
}

main() {
	intro

	read -p "Expected $EXTENSION_NAME version in VMs (e.g. 1.0.1512030601): " expected_extension_ver
	is_empty $expected_extension_ver && { err "Empty string passed"; exit 1; }

	check_deps
	check_asm
	set_subs

	delete_vms
	create_vms
	add_extension_to_vms
	validate_vms

	log "Test run is successful!"
	echo
	log "Cleaning up test artifacts..."
	delete_vms

	echo
	log "Done."
}


main
