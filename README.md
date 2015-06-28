# Azure Virtual Machine Extension for Docker

This repository contains source code for the Microsoft Azure Docker Virtual
Machine Extension.

The source code is meant to be used by Microsoft Azure employees publishing the
extension and the source code is open sourced under Apache 2.0 License for
reference. You can read the User Guide below.

* [Learn more: Azure Virtual Machine Extensions](https://msdn.microsoft.com/en-us/library/azure/dn606311.aspx)
* [How to use: Docker VM Extension](http://azure.microsoft.com/en-us/documentation/articles/virtual-machines-docker-vm-extension/)

Docker VM extension can:

- Install latest stable version Docker on your VM
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
  to JSON][yaml-to-json].

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

    $ azure vm extension set 'yourVMname' DockerExtension Microsoft.Azure.Extensions '1.0' \
    --public-config-path pub.json  \
    --private-config-path prot.json

In the command above, you can change version (1.0) with `'*'` to use latest
version available, or `'1.*'` to get newest version that does not introduce non-
breaking schema changes. To learn the latest version available, run:

    $ azure vm extension list

You can also omit `--public-config-parh` and/or `--private-config-path` if you
do not want to configure those settings.

-----

### Supported Linux Distributions

- CoreOS
- Ubuntu 13 and higher

Other Linux distributions are currently not supported and extension
is expected to fail on unsupported distributions.


### Debugging

After adding the extension, it can usually take a few minutes for the extension
to make it to the VM, install docker and do other things. You can see the
operation log of the extension at the
`/var/log/azure/<<extension version>>/docker-extension.log` file.

### Changelog

```
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
