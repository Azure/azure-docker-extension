#!/bin/bash
set -eou pipefail
IFS=$'\n\t'

# these flighting values should match Makefile
readonly TEST_SUBS_AZURE="c3dfd792-49a4-4b06-80fc-6fc6d06c4742"
readonly TEST_REGION_AZURE="South Central US"

readonly TEST_SUBS_AZURE_CHINA="cc1624c7-3f1d-4ed3-a855-668a86e96ad8"
readonly TEST_REGION_AZURE_CHINA="China East"

# make docker-cli send a lower version number so that we can
# test old images (if client>newer, docker engine rejects the request)
readonly DOCKER_REMOTE_API_VERSION=1.20

# supported images (add/update them as new major versions come out)
readonly DISTROS_AZURE=(
        "2b171e93f07c4903bcad35bda10acf22__CoreOS-Stable-1235.6.0" \
        "2b171e93f07c4903bcad35bda10acf22__CoreOS-Alpha-1298.1.0" \
        "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-14_04_5-LTS-amd64-server-20170110-en-us-30GB" \
        "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-16_04-LTS-amd64-server-20170113-en-us-30GB" \
        "5112500ae3b842c8b9c604889f8753c3__OpenLogic-CentOS-73-20161221"
)

readonly DISTROS_AZURE_CHINA=(
	"a54f4e2924a249fd94ad761b77c3e83d__CoreOS-Alpha-1192.0.0" \
	"a54f4e2924a249fd94ad761b77c3e83d__CoreOS-Stable-1122.2.0" \
	"b549f4301d0b4295b8e76ceb65df47d4__Ubuntu-14_04_3-LTS-amd64-server-20160627-en-us-30GB" \
	"b549f4301d0b4295b8e76ceb65df47d4__Ubuntu-16_04-LTS-amd64-server-20160627-en-us-30GB" \
	"f1179221e23b4dbb89e39d70e5bc9e72__OpenLogic-CentOS-71-20160329" \
	"f1179221e23b4dbb89e39d70e5bc9e72__OpenLogic-CentOS-72-20160617"
)

# Test constants
readonly SCRIPT_DIR=$(dirname $0)
readonly CONCURRENCY=10
readonly DOCKER_CERTS_DIR=dockercerts
readonly VM_PREFIX=dockerextensiontest-
readonly VM_USER=azureuser
readonly EXTENSION_NAME=DockerExtension
readonly EXTENSION_PUBLISHER=Microsoft.Azure.Extensions
readonly EXTENSION_CONFIG_AZURE=extensionconfig/public.json
readonly EXTENSION_CONFIG_AZURE_CHINA=extensionconfig/public-azurechina.json
readonly EXTENSION_CONFIG_PROT=extensionconfig/protected.json

# Global variables
expected_extension_version=
distros=
busybox_image_name=
extension_public_config=
domain_name=
test_subs=
test_region=

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

	Using test subscription: $test_subs
	Staging region to deploy VMs: $test_region

	EOF
}

set_subs() {
	log "Setting subscription to $test_subs..."
	azure account set $test_subs 1>/dev/null
}

try_cli() {
	log "Validating Azure CLI credentials"
	(
		set -x
		azure network application-gateway list
	)
	log "Azure CLI is authenticated"
}

ssh_key() {
	echo "$SCRIPT_DIR/id_rsa"
}

ssh_pub_key() {
	echo "$(ssh_key).pub"
}

generate_docker_certs() {
    ./gen_docker_certs.sh
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
	for d in "${distros[@]}"; do
		log " - $(trim_publisher $d)"
	done
	log "Total: ${#distros[@]} VM images."
}

vm_fqdn() {
	local name=$1
	echo "$name.$domain_name"
}

create_vms() {
	generate_ssh_keys
	print_distros

	local key=$(ssh_pub_key)
	local vm_count=${#distros[@]}
	local vm_names=$(parallel -j$CONCURRENCY echo $VM_PREFIX{} ::: $(seq 1 $vm_count))


	log "Creating test VMs in parallel..."

	# Print commands to be executed, then execute them
	local cmd="azure vm create {1} {2} -e 22 -l '$test_region' --no-ssh-password --ssh-cert '$key' $VM_USER"
	parallel --dry-run -j$CONCURRENCY --xapply $cmd ::: ${vm_names[@]} ::: ${distros[@]}
	parallel -j$CONCURRENCY --xapply $cmd 1>/dev/null ::: ${vm_names[@]} ::: ${distros[@]}

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

parse_minor_version() {
	# matches to major.minor in major.minor[.patch[.hotfix]]
	local v=$1
	echo $v | grep -Po "\d+\.[\d]+" | head -1
}

add_extension_to_vms() {
	local pub_config="$SCRIPT_DIR/$extension_public_config"
	local prot_config="$SCRIPT_DIR/$EXTENSION_CONFIG_PROT"

	# To use internal version, MAJOR.MINOR must be specified; not '*' or 'MAJOR.*'
	local minor_version=$(parse_minor_version $expected_extension_ver)
	log "Adding extension v${minor_version} to VMs in parallel..."

	local cmd="azure vm extension set {} $EXTENSION_NAME $EXTENSION_PUBLISHER '$minor_version' --public-config-path '$pub_config' --private-config-path '$prot_config'"
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

docker_cli_env() {
	local fqdn=$1
	echo "DOCKER_CERT_PATH=\"$(docker_cert_path)\" DOCKER_HOST=\"$(docker_addr $fqdn)\" DOCKER_API_VERSION=$DOCKER_REMOTE_API_VERSION"
}

wait_for_docker() {
	local host=$1
	local addr=$(docker_addr $host)

	local docker_certs="$(docker_cert_path)"

	# Validate "docker info" works
	local docker_env=$(docker_cli_env $host)
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
                        log "$docker_info_out"
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
	local docker_env=$(docker_cli_env $fqdn)
	local docker_cmd="docker --tls run --rm -i -v /var/lib/waagent:/agent ${busybox_image_name} ls -1 /agent | grep '^$prefix'"

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

validate_env() {
	local fqdn=$1
	local env_key=$2
	local env_val=$3

	local docker_env=$(docker_cli_env $fqdn)
	local docker_cmd="docker --tls run --rm -i -v /test:/test ${busybox_image_name} cat /test/env.txt"

	log "Validating environment variable '$env_key'."
	echo "+ $docker_env $docker_cmd"
	local i=0
	while true; do
		set +e
		local output="$(eval $docker_env $docker_cmd 2>&1)"
		set -e
		if [[ "$output" == *"$env_key=$env_val"* ]]; then
			log "Environment variable $env_val found in environment."
			return
		elif [[ $i -gt 5 ]]; then
			log "Environment file served does not contain env key: '$env_val':"
			echo "$output"
			exit 1
		fi
		i=$((i+1))
		printf '.'
		sleep 5
	done
}

get_container_names() {
	local fqdn=$1

	local docker_env=$(docker_cli_env $fqdn)
	local docker_cmd="docker --tls ps -a --format '{{.Names}}'"

	echo "$(eval $docker_env $docker_cmd 2>&1)"
}

validate_container_prefixes() {
	local fqdn=$1
	local prefix=$2

	local out=$(get_container_names $fqdn | grep -v "^${prefix}_")
	if [[ -n "$out" ]]; then
		log "DOCKER_COMPOSE_PROJECT setting is not effective."
		log "   Found containers without preconfigured prefix: $out"
		exit 1
	fi
	log "docker-compose container prefixes are correct."
}

vm_ssh_cmd() {
	local fqdn=$1
	echo "ssh -o \"StrictHostKeyChecking no\" -i '$(ssh_key)' ${VM_USER}@${fqdn}"
}

validate_vm() {
	local name=$1
	local fqdn=$(vm_fqdn $name)

	log "Validating $EXTENSION_NAME on VM '$name'"
	log "    (To debug issues: $(echo $(vm_ssh_cmd $fqdn)))"
	wait_for_docker $fqdn
	validate_extension_version $fqdn
	wait_for_container $fqdn
	validate_env $fqdn "SECRET_KEY" "SECRET_VALUE"
	validate_env $fqdn "COMPOSE_PROJECT_NAME" "test"
	validate_container_prefixes $fqdn "test"

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
	read -p "Expected $EXTENSION_NAME version in VMs (e.g. 1.2.2): " expected_extension_ver
	if [[ -z "$expected_extension_ver" ]]; then
		err "Empty string passed"
		exit 1
	fi
}

read_environment() {
	read -p "Enter the test environment name (e.g. AzureCloud, AzureChinaCloud. The default is AzureCloud): " test_environment
	case "$test_environment" in
		"" | "AzureCloud")
			distros=( "${DISTROS_AZURE[@]}" )
			extension_public_config=$EXTENSION_CONFIG_AZURE
			busybox_image_name="busybox"
			domain_name="cloudapp.net"
			test_subs=$TEST_SUBS_AZURE
			test_region=$TEST_REGION_AZURE
			;;
		"AzureChinaCloud")
			distros=( "${DISTROS_AZURE_CHINA[@]}" )
			extension_public_config=$EXTENSION_CONFIG_AZURE_CHINA
			busybox_image_name="mirror.azure.cn:5000/library/busybox"
			domain_name="chinacloudapp.cn"
			test_subs=$TEST_SUBS_AZURE_CHINA
			test_region=$TEST_REGION_AZURE_CHINA
			;;
		*)
			err "Invalid environment name"
			exit 1
	esac
}

check_deps
intro
read_version
read_environment
check_asm
set_subs
try_cli

delete_vms
generate_docker_certs
create_vms
add_extension_to_vms
validate_vms

log "Test run is successful!"
log "Cleaning up test artifacts..."
delete_vms
log "Success."
