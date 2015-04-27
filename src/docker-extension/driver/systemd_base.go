package driver

import (
	"executil"
)

type systemdBaseDriver struct{}

func (d systemdBaseDriver) RestartDocker() error {
	if err := executil.ExecPipe("systemctl", "daemon-reload"); err != nil {
		return err
	}
	return executil.ExecPipe("systemctl", "restart", "docker")
}

func (d systemdBaseDriver) StopDocker() error {
	return executil.ExecPipe("systemctl", "stop", "docker")
}
