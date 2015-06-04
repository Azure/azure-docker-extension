package driver

import (
	"executil"
)

type upstartBaseDriver struct{}

func (d upstartBaseDriver) RestartDocker() error {
	if err := executil.ExecPipe("update-rc.d", "docker", "defaults"); err != nil {
		return err
	}
	return executil.ExecPipe("service", "docker", "restart")
}

func (d upstartBaseDriver) StopDocker() error {
	return executil.ExecPipe("service", "docker", "stop")
}
