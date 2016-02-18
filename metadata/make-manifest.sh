#!/bin/sh
set -e

readonly SCRIPT_DIR=$(dirname $0)

echo "Make sure you ran 'make bundle' before running this." >&2
echo "This script will upload the package and create a manifest XML. Save it to a file." >&2

read -p "Extension Version: " version 1>&2
pkg_path="$(readlink -f "$SCRIPT_DIR/../bundle/docker-extension.zip")"

set -x
azure-extensions-cli new-extension-manifest \
	--package "$pkg_path" \
	--storage-account dockerextension \
	--namespace Microsoft.Azure.Extensions \
	--name DockerExtension \
	--supported-os Linux \
	--label 'Docker Extension' \
	--description 'Microsoft Azure Docker Extension for Linux' \
	--eula-url 'https://github.com/Azure/azure-docker-extension/blob/master/LICENSE' \
	--privacy-url 'http://www.microsoft.com/privacystatement/en-us/OnlineServices/Default.aspx' \
	--homepage-url  'https://github.com/Azure/azure-docker-extension' \
	--company 'Microsoft' \
	--version "$version"
