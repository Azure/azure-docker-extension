package driver

import (
	"fmt"
	"github.com/Azure/azure-docker-extension/pkg/executil"
)

// CentOSDriver is for CentOS-based distros.
type CentOSDriver struct {
	systemdBaseDriver
	systemdUnitOverwriteDriver
}

func (c CentOSDriver) InstallDocker(azureEnv string) error {
	switch azureEnv {
		case "AzureCloud":
			return executil.ExecPipe("/bin/sh", "-c", "curl -sSL https://get.docker.com/ | sh")
		case "AzureChinaCloud":
			return executil.ExecPipe("/bin/sh", "-c", "curl -sSL https://mirror.azure.cn/repo/install-docker-engine.sh | sh -s -- --mirror AzureChinaCloud")
		default:
			return fmt.Errorf("invalid environment name %s", azureEnv)
	}
}

func (c CentOSDriver) UninstallDocker() error {
	return executil.ExecPipe("yum", "-y", "-q", "remove", "docker-engine.x86_64")
}

func (c CentOSDriver) DockerComposeDir() string { return "/usr/local/bin" }

func (c CentOSDriver) BaseOpts() []string {
	// centos socket activation is removed from get.docker.com installation script
	// therefore we don't use -H=fd:// on centos. See more context here:
	// - https://github.com/docker/docker/issues/23793
	// - https://github.com/docker/docker/pull/24804
	return []string{"-H=unix://"}
}
