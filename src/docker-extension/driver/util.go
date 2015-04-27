package driver

import (
	"docker-extension/dockeropts"
	"fmt"
	"io/ioutil"
)

func rewriteOpts(e dockeropts.Editor, cfgFile string, args string) error {
	in, err := ioutil.ReadFile(cfgFile)
	if err != nil {
		return fmt.Errorf("error reading %s: %v", cfgFile, err)
	}

	out, err := e.ChangeOpts(string(in), args)
	if err != nil {
		return fmt.Errorf("error updating settings at %s: %v", cfgFile, err)
	}

	if err := ioutil.WriteFile(cfgFile, []byte(out), 0644); err != nil {
		return fmt.Errorf("error writing to %s: %v", cfgFile, err)
	}
	return nil
}
