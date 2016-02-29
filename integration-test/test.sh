#!/bin/bash
set -eou pipefail
IFS=$'\n\t'

# these flighting values should match Makefile
readonly TEST_SUBS="c3dfd792-49a4-4b06-80fc-6fc6d06c4742"
readonly TEST_REGION="Brazil South"

# supported images (add/update them as new major versions come out)
readonly DISTROS=(
	"2b171e93f07c4903bcad35bda10acf22__CoreOS-Stable-835.9.0" \
	"b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-14_04_3-LTS-amd64-server-20151117-en-us-30GB" \
	"b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-15_10-amd64-server-20160222-en-us-30GB" \
	"5112500ae3b842c8b9c604889f8753c3__OpenLogic-CentOS-71-20150731" \
	)

# Test constants
readonly SCRIPT_DIR=$(dirname $0)
readonly CONCURRENCY=10
readonly DOCKER_CERTS_DIR=dockercerts
readonly VM_PREFIX=dockerextensiontest-
readonly VM_USER=azureuser
readonly EXTENSION_NAME=DockerExtension
readonly EXTENSION_PUBLISHER=Microsoft.Azure.Extensions
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

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

check_deps() {
	local deps=(azure jq docker curl parallel)

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

	if [[ -f "$key" ]] && [[ -f "$pub" ]];then
		# no need to regenerate keys
		return
	fi

	log "Generating SSH keys..."
	rm -f "$key" "$pub"
	ssh-keygen -q -f "$key" -N ""
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
	log "Total: ${#DISTROS[@]} VM images."
}

vm_fqdn() {
	local name=$1
	echo "$name.cloudapp.net"	
}

create_vms() {
	generate_ssh_keys
	print_distros

	local key=$(ssh_pub_key)
	local vm_count=${#DISTROS[@]}
	local vm_names=$(parallel -j$CONCURRENCY echo $VM_PREFIX{} ::: $(seq 1 $vm_count))


	log "Creating test VMs in parallel..."

	# Print commands to be executed, then execute them
	local cmd="azure vm create {1} {2} -e 22 -l '$TEST_REGION' --no-ssh-password --ssh-cert '$key' $VM_USER"
	parallel --dry-run -j$CONCURRENCY --xapply $cmd ::: ${vm_names[@]} ::: ${DISTROS[@]}
	parallel -j$CONCURRENCY --xapply $cmd 1>/dev/null ::: ${vm_names[@]} ::: ${DISTROS[@]}

	log "Opening up ports in parallel..."
	local ports=( 80 2376 )
	for port in "${ports[@]}"; do # ports need to be added one by one for a single VM
		local cmd="azure vm endpoint create {1} $port $port"
		parallel --dry-run -j$CONCURRENCY $cmd ::: ${vm_names[@]}
		parallel -j$CONCURRENCY $cmd 1>/dev/null ::: ${vm_names[@]}
	done
}

get_vms() {
	local list_json=$(azure vm list --json)
	echo $list_json | jq -r '.[].VMName' | grep "^$VM_PREFIX" | sort -n
}

delete_vms() {
	log "Cleaning up test VMs in parallel..."

	local cmd="azure vm delete -b -q {}"
	local vms=$(get_vms)

	if [[ -z "$vms" ]]; then
		return
	fi

	# Print commands to be executed, then execute them
	parallel --dry-run -j$CONCURRENCY "$cmd" ::: "${vms[@]}"
	parallel -j$CONCURRENCY "$cmd" 1>/dev/null ::: "${vms[@]}"

	log "Cleaned up all test VMs."
}

add_extension_to_vms() {
	log "Adding extension to VMs in parallel..."

	local pub_config="$SCRIPT_DIR/$EXTENSION_CONFIG"
	local prot_config="$SCRIPT_DIR/$EXTENSION_CONFIG_PROT"

	local cmd="azure vm extension set {} $EXTENSION_NAME $EXTENSION_PUBLISHER '*' --public-config-path '$pub_config' --private-config-path '$prot_config'"
	local vms=$(get_vms)

	# Print commands to be executed, then execute them
	parallel --dry-run -j$CONCURRENCY "$cmd" ::: "${vms[@]}"
	parallel -j$CONCURRENCY "$cmd" 1>/dev/null ::: "${vms[@]}"

	log "Added $EXTENSION_NAME to all test VMs."
}

docker_addr() {
	local fqdn=$1
	echo "tcp://$fqdn:2376"
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
	echo "+ $docker_env $docker_cmd"
	
	while true; do
		set +e # ignore errors b/c the following command will retry
		eval $docker_env $docker_cmd 1>/dev/null 2>&1
		local exit_code=$?
		set -e

		if [ $exit_code -ne 0 ]; then
			printf '.'
			sleep 5
		else
			log "Authenticated to docker engine at $addr."
			# Check if docker.options in public.json took effect
			local docker_info_out="$(eval $docker_env $docker_cmd 2>&1)"
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
		set +e # ignore errors b/c the following command will retry
		eval $curl_cmd 2>&1 1>/dev/null
		local exit_code=$?
		set -e

		if [ $exit_code -eq 0 ]; then
			log "Web server container is up."
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
	if [[ -z "$version" ]]; then
		err "Could not locate $EXTENSION_NAME version."
		exit 1
	fi
	
	if [[ "$version" != "$expected_extension_ver" ]]; then
		err "Wrong $EXTENSION_NAME encountered: '$version' (expected: '$expected_extension_ver')."
		exit 1
	fi
	log "VM has the correct version of $EXTENSION_NAME."
}

validate_secret_env() {
	local fqdn=$1
	local docker_env="DOCKER_CERT_PATH=\"$(docker_cert_path)\" DOCKER_HOST=\"$(docker_addr $fqdn)\""
	local docker_cmd="docker --tls run --rm -i -v /test:/test busybox cat /test/env.txt"

	log "Validating protected environment variable."
	echo "+ $docker_env $docker_cmd"
	local i=0
	while true; do
		set +e
		local output="$(eval $docker_env $docker_cmd 2>&1)"
		set -e
		if [[ "$output" == *"SECRET_KEY=SECRET_VALUE"* ]]; then
			log "Secret variable found in environment."
			return
		elif [[ $i -gt 5 ]]; then
			log "Environment file served does not contain protected env key 'SECRET_KEY':"
			echo "$output"
			exit 1
		fi
		(( i++ ))
		print '.'
		sleep 5
	done

}

vm_ssh_cmd() {
	local fqdn=$1
	echo "ssh -i '$(ssh_key)' ${VM_USER}@${fqdn}"
}

validate_vm() {
	local name=$1
	local fqdn=$(vm_fqdn $name)

	log "Validating $EXTENSION_NAME on VM '$name'"
	log "    (To debug issues: $(echo $(vm_ssh_cmd $fqdn)))"
	wait_for_docker $fqdn
	validate_extension_version $fqdn
	wait_for_container $fqdn
	validate_secret_env $fqdn

	log "VM is O.K.: $name."
	echo
}

validate_vms() {
	log "Validating VMs..."		
	local vms=$(get_vms)
	for vm in $vms; do
		validate_vm "$vm"
	done
}

read_version() {
	read -p "Expected $EXTENSION_NAME version in VMs (e.g. 1.0.1512030601): " expected_extension_ver
	if [[ -z "$expected_extension_ver" ]]; then
		err "Empty string passed"
		exit 1
	fi
}

check_deps
intro
read_version
check_asm
set_subs

delete_vms
create_vms
add_extension_to_vms
validate_vms

log "Test run is successful!"
log "Cleaning up test artifacts..."
delete_vms
log "Success."
