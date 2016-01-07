package driver

import (
	"fmt"
	"io/ioutil"

	"github.com/Azure/azure-docker-extension/pkg/dockeropts"
	"github.com/Azure/azure-docker-extension/pkg/util"
)

// rewriteOpts uses the specified dockeropts editor to modify the existing cfgFile
// (if not exists, it creates the cfg file and its directory) with specified args.
// If nothing is changed, this will return false.
func rewriteOpts(e dockeropts.Editor, cfgFile string, args string) (restartNeeded bool, err error) {
	in, err := ioutil.ReadFile(cfgFile)
	if err != nil {
		return false, fmt.Errorf("error reading %s: %v", cfgFile, err)
	}

	out, err := e.ChangeOpts(string(in), args)
	if err != nil {
		return false, fmt.Errorf("error updating settings at %s: %v", cfgFile, err)
	}

	// check if existing config file needs an update
	if ok, _ := util.PathExists(cfgFile); ok {
		existing, err := ioutil.ReadFile(cfgFile)
		if err != nil {
			return false, fmt.Errorf("error reading %s: %v", cfgFile, err)
		}

		// no need to update config or restart service if goal config is already there
		if string(existing) == out {
			return false, nil
		}
	}

	if err := ioutil.WriteFile(cfgFile, []byte(out), 0644); err != nil {
		return false, fmt.Errorf("error writing to %s: %v", cfgFile, err)
	}
	return true, nil
}
