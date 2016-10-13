package driver

import (
	"fmt"
	"github.com/Azure/azure-docker-extension/pkg/executil"
)

type ubuntuBaseDriver struct{}

func (u ubuntuBaseDriver) InstallDocker(azureEnv string) error {
	switch azureEnv {
		case "AzureCloud":
			return executil.ExecPipe("/bin/sh", "-c", "wget -qO- https://get.docker.com/ | sh")
		case "AzureChinaCloud":
			return executil.ExecPipe("/bin/sh", "-c", "wget -qO- https://mirror.azure.cn/repo/install-docker-engine.sh | sh -s -- --mirror AzureChinaCloud")
		default:
			return fmt.Errorf("invalid environemnt name: %s", azureEnv)
	}
}

func (u ubuntuBaseDriver) UninstallDocker() error {
	if err := executil.ExecPipe("apt-get", "-qqy", "purge", "docker-engine"); err != nil {
		return err
	}
	return executil.ExecPipe("apt-get", "-qqy", "autoremove")
}

func (u ubuntuBaseDriver) DockerComposeDir() string { return "/usr/local/bin" }
