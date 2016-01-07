package driver

import (
	"github.com/Azure/azure-docker-extension/pkg/dockeropts"
	"github.com/Azure/azure-docker-extension/pkg/executil"
)

type systemdBaseDriver struct{}

func (d systemdBaseDriver) RestartDocker() error {
	if err := executil.ExecPipe("systemctl", "daemon-reload"); err != nil {
		return err
	}
	return executil.ExecPipe("systemctl", "restart", "docker")
}

func (d systemdBaseDriver) StartDocker() error {
	return executil.ExecPipe("systemctl", "start", "docker")
}

func (d systemdBaseDriver) StopDocker() error {
	return executil.ExecPipe("systemctl", "stop", "docker")
}

// systemdUnitOverwriteDriver is for distros where we modify docker.service
// file in-place.
type systemdUnitOverwriteDriver struct{}

func (u systemdUnitOverwriteDriver) UpdateDockerArgs(args string) (bool, error) {
	const cfg = "/lib/systemd/system/docker.service"
	e := dockeropts.SystemdUnitEditor{}
	return rewriteOpts(e, cfg, args)
}

func (u systemdUnitOverwriteDriver) BaseOpts() []string {
	return []string{"daemon", "-H=fd://"}
}
