package driver

import (
	"docker-extension/dockeropts"
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
