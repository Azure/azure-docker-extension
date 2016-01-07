package driver

import (
	"github.com/Azure/azure-docker-extension/pkg/executil"
)

type upstartBaseDriver struct{}

func (d upstartBaseDriver) RestartDocker() error {
	if err := executil.ExecPipe("update-rc.d", "docker", "defaults"); err != nil {
		return err
	}
	return executil.ExecPipe("service", "docker", "restart")
}

func (d upstartBaseDriver) StartDocker() error {
	return executil.ExecPipe("service", "docker", "start")
}

func (d upstartBaseDriver) StopDocker() error {
	return executil.ExecPipe("service", "docker", "stop")
}
