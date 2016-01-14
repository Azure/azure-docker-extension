# Azure Virtual Machine Extension for Docker

This repository contains source code for the Microsoft Azure Docker Virtual
Machine Extension.

The source code is meant to be used by Microsoft Azure employees publishing the
extension and the source code is open sourced under Apache 2.0 License for
reference. You can read the User Guide below.

* [Learn more: Azure Virtual Machine Extensions](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-extensions-features/)
* [How to use: Docker VM Extension](http://azure.microsoft.com/en-us/documentation/articles/virtual-machines-docker-vm-extension/)

Docker VM extension can:

- Install latest stable version of Docker Engine on your Linux VM
- If provided, configures Docker daemon to listen on specified port, with given
  certs
- If provided, launches the given containers using docker-compose

# User Guide

## 1. Configuration schema

### 1.1. Public configuration keys

Schema for the public configuration file for the Docker Extension looks like
this:

* `docker`: (optional, JSON object)
  * `port`: (optional, string) the port Docker listens on
  * `options`: (optional, string array) command line options passed to the
    Docker engine
* `compose`: (optional, JSON object) the compose.yml file to be used, [converted
  to JSON][yaml-to-json]. If you are considering to embed secrets as environment
  variables in this section, please see the `"environment"` key described below.

A minimal simple configuration would be an empty json object (`{}`) or a more
advanced one like this:
  
```json
{
	"docker":{
		"port": "2376",
		"options": ["-D", "--dns=8.8.8.8"]
	},
	"compose": {
		"cache" : {
			"image" : "memcached",
			"ports" : ["11211:11211"]
		},
		"blog": {
			"image": "ghost",
			"ports": ["80:2368"]
		}
	}
}
```

> **NOTE:** It is not suggested to specify `"port"` unless you are going to
specify `"certs"` configuration (described below) as well. This can open up
the Docker engine to public internet without authentication.

### 1.2. Protected configuration keys

Schema for the protected configuration file stores the secrets that are passed
to the Docker engine looks like this:

* `environment`: (optional, JSON object) Key value pairs to store environment variables
  to be passed to `docker-compose` securely. By using this, you can avoid embedding secrets
  in the unencrypted `"compose"` section.
* `certs`: (optional, JSON object)
  * `ca`: (required, string): base64 encoded CA certificate, passed to the engine as `--tlscacert`
  * `cert`: (required, string): base64 encoded TLS certificate, passed to the engine as `--tlscert`
  * `key`: (required, string): base64 encoded TLS key, passed to the engine as `--tlskey`
* `login`: (optional, JSON object) login credentials to log in to a Docker Registry
  * `server`: (string, optional) registry server, if not specified, logs in to Docker Hub
  * `username`: (string, required)
  * `password`: (string, required)
  * `email`: (string, required)

In order to encode your existing Docker certificates to base64, you can run:

    $ cat ~/.docker/ca.pem | base64

An advanced configuration that configures TLS for Docker engine and logs in to
Docker Hub account would look like this:

```json
{
    "environment" : {
        "SECRET_ENV": "<<secret-value>>",
	"MYSQL_ROOT_PASSWORD": "very-secret-password"
    },
    "certs": {
    	"ca": "<<base64 encoded ~/docker/ca.pem>>",
        "cert": "<<base64 encoded ~/docker/cert.pem>>",
        "key": "<<base64 encoded ~/docker/key.pem>>"
    },
    "login": {
    	"username": "myusername",
        "password": "mypassword",
        "email": "name@example.com"
    }
}
```

## 2. Deploying the Extension to a VM

Using [**Azure CLI**][azure-cli]: Once you have a VM created on Azure and
configured your `pub.json` and `prot.json` (in section 1.1 and 1.2 above), you
can add the Docker Extension to the virtual machine by running:

    $ azure vm extension set 'yourVMname' DockerExtension Microsoft.Azure.Extensions '1.1' \
    --public-config-path pub.json  \
    --private-config-path prot.json

In the command above, you can change version with `'*'` to use latest
version available, or `'1.*'` to get newest version that does not introduce non-
breaking schema changes. To learn the latest version available, run:

    $ azure vm extension list

You can also omit `--public-config-path` and/or `--private-config-path` if you
do not want to configure those settings.

## 3. Using Docker Extension in ARM templates

You can provision Docker Extension in [Azure Resource templates](https://azure.microsoft.com/en-us/documentation/articles/resource-group-authoring-templates/)
by specifying it just like a resource in your template. The configuration keys
go to `"settings"` section and (optionally) protected keys go to `"protectedSettings"` section.

Example resource definition:

```json
{
  "type": "Microsoft.Compute/virtualMachines/extensions",
  "name": "[concat(variables('vmName'), '/DockerExtension'))]",
  "apiVersion": "2015-05-01-preview",
  "location": "[parameters('location')]",
  "dependsOn": [
    "[concat('Microsoft.Compute/virtualMachines/', variables('vmName'))]"
  ],
  "properties": {
    "publisher": "Microsoft.Azure.Extensions",
    "type": "DockerExtension",
    "typeHandlerVersion": "1.1",
    "autoUpgradeMinorVersion": true,
    "settings": {},
    "protectedSettings": {}
  }
}
```

You can find various usages of this at the following gallery templates:

* https://github.com/Azure/azure-quickstart-templates/blob/master/docker-simple-on-ubuntu/azuredeploy.json
* https://github.com/Azure/azure-quickstart-templates/tree/master/docker-wordpress-mysql
* https://github.com/Azure/azure-quickstart-templates/tree/master/docker-swarm-cluster

-----

### Supported Linux Distributions

- CoreOS
- Ubuntu 13 and higher
- CentOS 7.1 and higher
- Red Hat Enterprise Linux (RHEL) 7.1 and higher

Other Linux distributions are currently not supported and extension
is expected to fail on unsupported distributions.


### Debugging

After adding the extension, it can usually take a few minutes for the extension
to make it to the VM, install docker and do other things. You can see the
operation log of the extension at the
`/var/log/azure/<<extension version>>/docker-extension.log` file.

### Changelog

```
# 1.1.1601140348 (2016-01-13)
- Fix: eliminate redundant restarts of docker-engine on CoreOS if configuration
  is not changed.

# 1.1.1601070410 (2016-01-06)
- Fix: eliminate redundant restarting of docker-engine. This avoids restart of
  docker-engine service (and thus containers) when (1) VM boots (2) waagent
  calls extension's enable command in case of GoalState changes such as Load
  Balancer updates.
- Fix: Write .status file before forking into background in 'enable' command.
  This is a workaround for waagent 2.1.x.

# 1.1.1512180541 (2015-12-17)
- Security fix: prevent clear-text registry credentials from being logged.

# 1.1.1512090359 (2015-12-08)
- Introduced secure delivery of secrets through "environment" section of
  protected configuration to be passed to docker-compose. Users do not have
  to embed secrets in the "compose" section anymore.

# 1.0.1512030601 (2015-12-02)
- Added support for CentOS and Red Hat Enterprise Linux (RHEL).

# 1.0.1512020618 (2015-12-01)
- Bumped docker-compose version from v1.4.1 to v1.5.1.
- Added retry logic around installation as a mitigation for a VM scale set
  issue.

# 1.0.1510142311 (2015-10-14)
- Configured docker-compose timeout to 15 minutes to prevent big images
  from failing to be pulled down intermittently due to network conditions.

# 1.0.1509171835 (2015-09-18)
- Move 'install' stage to 'enable' step so that installation is not killed by
  5-minute waagent timeout on slow regions and distros (such as Ubuntu LTS)
  with many missing dependency packages.
- Bump docker-compose to v1.4.0 from v1.3.2.
- Extension now uninstalls docker-compose on 'uninstall' stage.

# 1.0.1509160543 (2015-09-16)
- Workaround for undesirable behavior in WALA: Write .seqnum file to /tmp to
  prevent multiple simultaneous calls to the extension with the same sequence
  number.

# 1.0.1508121604 (2015-08-12)
- Replaced '--daemon' flag with daemon due to breaking behavior introduced in
  docker-1.8.0 release.

# 1.0.1507232004 (2015-07-23)
- Updating the apt package name for uninstall step.

# 1.0.1507151643 (2015-07-15)
- Bump docker-compose to v1.3.2 from v1.2.0. (gh#41)

# 1.0.1507110733 (2015-07-11)
- Workaround for a bug caused from docker-compose to crash with error
  'write /dev/stderr: broken pipe'

# 1.0.1507101636 (2015-07-10)
- Bug fix (gh#38). Blocking on install step instead of forking and running in
  background.

# 1.0.1507020203 (2015-07-01)
- Better docker-compose integration and prevent duplicate container creations
  between reboots.
- Fork and run in background install/enable steps to avoid waagent time limits.

# 1.0.1506280321 (2015-06-27)
- "certs" that are not base64-encoded are also accepted now. This provides more
  backwards compatibility with the existing format in the old extension.
- Docker certs are now overwritten on every 'enable' run using the extension
  configuration.
- Placed certs server-cert.pem/server-key.pem are renamed to cert.pem/key.pem to
  be consistent with Docker's nomenclature. The change should be automatically
  picked up upon reboot.

# 1.0.1506141804 (2015-06-14)
- Privacy Policy link update

# 1.0.1506090235 (2015-06-09)
- Bug fix

# 1.0.1506041832 (2015-06-04)
- Initial release
```

[yaml-to-json]: http://yamltojson.com/
[azure-cli]: https://azure.microsoft.com/en-us/documentation/articles/xplat-cli/
