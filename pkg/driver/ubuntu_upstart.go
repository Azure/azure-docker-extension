package driver

import (
	"github.com/Azure/azure-docker-extension/pkg/dockeropts"
)

type UbuntuUpstartDriver struct {
	ubuntuBaseDriver
	upstartBaseDriver
}

func (u UbuntuUpstartDriver) BaseOpts() []string {
	return []string{"-H=unix://"}
}

func (u UbuntuUpstartDriver) UpdateDockerArgs(args string) (bool, error) {
	const cfgPath = "/etc/default/docker"
	e := dockeropts.UpstartCfgEditor{}
	return rewriteOpts(e, cfgPath, args)
}
