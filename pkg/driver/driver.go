package driver

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/Azure/azure-docker-extension/pkg/distro"
)

type DistroDriver interface {
	InstallDocker() error
	DockerComposeDir() string

	BaseOpts() []string
	ChangeOpts(args string) error

	RestartDocker() error
	StopDocker() error
	UninstallDocker() error
}

func GetDriver(d distro.Info) (DistroDriver, error) {
	if d.Id == "CoreOS" {
		return CoreOSDriver{}, nil
	} else if d.Id == "Ubuntu" {
		parts := strings.Split(d.Release, ".")
		if len(parts) == 0 {
			return nil, fmt.Errorf("invalid ubuntu version format: %s", d.Release)
		}
		major, err := strconv.Atoi(parts[0])
		if err != nil {
			return nil, fmt.Errorf("can't parse ubuntu version number: %s", parts[0])
		}

		// - <13: not supportted
		// - 13.x, 14.x : uses upstart
		// - 15.x+: uses systemd
		if major < 13 {
			return nil, fmt.Errorf("Ubuntu 12 or older not supported. Got: %s", d)
		} else if major < 15 {
			return UbuntuUpstartDriver{}, nil
		} else {
			return UbuntuSystemdDriver{}, nil //TODO fix with systemd
		}
	}

	return nil, fmt.Errorf("Distro not supported: %s", d)
}
