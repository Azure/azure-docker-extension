package driver

// RHELDriver is for Red Hat Enterprise Linux.
type RHELDriver struct {
	CentOSDriver
}

// DockerComposeDir for RHEL is different than CentOSDriver as CentOS
// has /usr/local/bin in $PATH and RHEL does not. Therefore using /usr/bin.
func (r RHELDriver) DockerComposeDir() string { return "/usr/bin" }
