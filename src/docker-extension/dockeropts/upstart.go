package dockeropts

import (
	"bufio"
	"fmt"
	"strings"
)

// UpstartCfgEditor finds the line that contains 'DOCKER_OPTS=' and
// replaces with the given args. If not found, appends a new line
// with given configuration.
type UpstartCfgEditor struct{}

func (e UpstartCfgEditor) ChangeOpts(contents, args string) (string, error) {
	var (
		out      = []string{}
		sc       = bufio.NewScanner(strings.NewReader(contents))
		replaced = false
		cfg      = fmt.Sprintf(`DOCKER_OPTS="%s"`, args)
	)

	for sc.Scan() {
		line := sc.Text()
		if !replaced && strings.Contains(line, "DOCKER_OPTS=") {
			replaced = true
			line = cfg
		}
		out = append(out, line)
	}
	if err := sc.Err(); err != nil {
		return "", err
	}
	if !replaced {
		out = append(out, cfg)
	}
	// Reconstruct
	file := strings.Join(out, "\n")
	return file, nil
}
