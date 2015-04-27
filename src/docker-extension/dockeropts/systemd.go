package dockeropts

import (
	"errors"
	"fmt"
	"regexp"
)

// SystemdUnitEditor modifies the 'ExecStart=' line as
// 'ExecStart=/usr/bin/docker $args'. If ExecStart line does not
// exist, returns error.
type SystemdUnitEditor struct{}

func (e SystemdUnitEditor) ChangeOpts(contents, args string) (string, error) {
	cmd := fmt.Sprintf("ExecStart=/usr/bin/docker %s", args)
	r := regexp.MustCompile("ExecStart=.*")

	if r.FindString(contents) == "" {
		return "", errors.New("systemd unit editor could not find ExecStart")
	}
	return string(r.ReplaceAllString(contents, cmd)), nil
}
