package distro

import (
	"fmt"
	"io/ioutil"
	"os"
	"regexp"

	"github.com/Azure/azure-docker-extension/pkg/util"
)

const (
	lsbReleasePath    = "/etc/lsb-release"
	redhatReleasePath = "/etc/redhat-release"
	centosReleasePath = "/etc/centos-release"

	RhelID   = "Red Hat Enterprise Linux Server"
	CentosID = "CentOS"
)

type Info struct{ Id, Release string }

func (d Info) String() string {
	return fmt.Sprintf("%s %s", d.Id, d.Release)
}

type distroReleaseInfo interface {
	Get() (Info, error)
}

// lsbReleaseInfo parses /etc/lsb-release to return Distro
// ID and Release Number
type lsbReleaseInfo struct{}

func (l lsbReleaseInfo) Get() (Info, error) {
	b, err := ioutil.ReadFile(lsbReleasePath)
	if err != nil && os.IsNotExist(err) {
		return Info{}, fmt.Errorf("Could not find distro info at %s", lsbReleasePath)
	}

	return l.parse(b)
}

func (l lsbReleaseInfo) parse(b []byte) (Info, error) {
	var d Info
	m, err := util.ParseINI(string(b))
	if err != nil {
		return d, fmt.Errorf("Error parsing distro info: %v. info=%q", err, b)
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
			return d, fmt.Errorf("Key %s not found in LSB info. info=%q", f.key, b)
		}
		*f.val = v
	}
	return d, nil
}

// centosReleaseInfo parses release information of distributions in CentOS family such as
// RHEL and CentOS from /etc/redhat-release and /etc/centos-release.
type centosReleaseInfo struct {
	path   string
	distro string
}

// parseVersion extracts a version string from given release string or returns empty string
// if it is not found. Version should be in form 'n.n.[n.[n.[...]]]'
func (c centosReleaseInfo) parseVersion(release []byte) string {
	r := regexp.MustCompile(`[\d+\.]+[\d+]`)
	return string(r.Find([]byte(release)))
}

func (c centosReleaseInfo) Get() (Info, error) {
	b, err := ioutil.ReadFile(c.path)
	if err != nil && os.IsNotExist(err) {
		return Info{}, fmt.Errorf("Could not find distro info at %s", c.path)
	}

	version := c.parseVersion(b)
	if version == "" {
		return Info{}, fmt.Errorf("cannot extract version from release string: %q", b)
	}
	return Info{
		Id:      c.distro,
		Release: version,
	}, nil
}

func GetDistro() (Info, error) {
	src, err := releaseInfoSource()
	if err != nil {
		return Info{}, err
	}
	return src.Get()
}

func releaseInfoSource() (distroReleaseInfo, error) {
	// LSB
	if ok, err := util.PathExists(lsbReleasePath); err != nil {
		return nil, err
	} else if ok {
		return lsbReleaseInfo{}, nil
	}

	// RedHat/CentOS. Checking for CentOS first as CentOS contains
	// both centos-release and redhat-release and this path-existence
	// check makes it look like RHEL.
	if ok, err := util.PathExists(centosReleasePath); err != nil {
		return nil, err
	} else if ok {
		return centosReleaseInfo{centosReleasePath, CentosID}, nil
	}
	if ok, err := util.PathExists(redhatReleasePath); err != nil {
		return nil, err
	} else if ok {
		return centosReleaseInfo{redhatReleasePath, RhelID}, nil
	}

	// Unknown
	return nil, fmt.Errorf("could not determine distro")
}
