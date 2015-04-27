package distro

import (
	util "docker-extension/util"
	"fmt"
	"io/ioutil"
	"os"
)

const (
	distroPath = "/etc/lsb-release"
)

type Info struct{ Id, Release string }

func (d Info) String() string {
	return fmt.Sprintf("%s %s", d.Id, d.Release)
}

func GetDistro() (Info, error) {
	var d Info
	b, err := ioutil.ReadFile(distroPath)
	if err != nil && os.IsNotExist(err) {
		return d, fmt.Errorf("Could not find distro info at %s", distroPath)
	}

	m, err := util.ParseINI(string(b))
	if err != nil {
		return d, fmt.Errorf("Error parsing distro info %s: %v", distroPath, err)
	}

	fields := []struct {
		key string
		val *string
	}{
		{"DISTRIB_ID", &d.Id},
		{"DISTRIB_RELEASE", &d.Release},
	}
	for _, f := range fields {
		v, ok := m[f.key]
		if !ok {
			return d, fmt.Errorf("Key %s not found in %s", f.key, distroPath)
		}
		*f.val = v
	}
	return d, nil
}
