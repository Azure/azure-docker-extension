package driver

import (
	"github.com/Azure/azure-docker-extension/pkg/executil"
)

type ubuntuBaseDriver struct{}

func (u ubuntuBaseDriver) InstallDocker() error {
	return executil.ExecPipe("/bin/sh", "-c", "wget -qO- https://get.docker.com/ | sh")
}

func (u ubuntuBaseDriver) UninstallDocker() error {
	if err := executil.ExecPipe("apt-get", "-qqy", "purge", "docker-engine"); err != nil {
		return err
	}
	return executil.ExecPipe("apt-get", "-qqy", "autoremove")
}

func (u ubuntuBaseDriver) DockerComposeDir() string { return "/usr/local/bin" }
