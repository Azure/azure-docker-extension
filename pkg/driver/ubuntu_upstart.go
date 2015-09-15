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

func (u UbuntuUpstartDriver) ChangeOpts(args string) error {
	const cfg = "/etc/default/docker"
	e := dockeropts.UpstartCfgEditor{}
	return rewriteOpts(e, cfg, args)
}
