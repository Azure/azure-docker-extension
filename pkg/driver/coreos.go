package driver

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"

	"github.com/Azure/azure-docker-extension/pkg/util"
)

// CoreOS: distro already comes with docker installed and
// uses systemd as init system.
type CoreOSDriver struct {
	systemdBaseDriver
}

func (c CoreOSDriver) InstallDocker(azureEnv string) error {
	log.Println("CoreOS: docker already installed, noop")
	return nil
}
func (c CoreOSDriver) UninstallDocker() error {
	log.Println("CoreOS: docker cannot be uninstalled, noop")
	return nil
}

func (c CoreOSDriver) DockerComposeDir() string { return "/opt/bin" }

func (c CoreOSDriver) BaseOpts() []string { return []string{} }

func (c CoreOSDriver) UpdateDockerArgs(args string) (bool, error) {
	const dropInDir = "/run/systemd/system/docker.service.d"
	const dropInFile = "10-docker-extension.conf"
	filePath := filepath.Join(dropInDir, dropInFile)

	config := fmt.Sprintf(`[Service]
Environment="DOCKER_OPTS=%s"`, args)

	// check if config file exists and needs an update
	if ok, _ := util.PathExists(filePath); ok {
		existing, err := ioutil.ReadFile(filePath)
		if err != nil {
			return false, fmt.Errorf("error reading %s: %v", filePath, err)
		}

		// no need to update config or restart service if goal config is already there
		if string(existing) == config {
			return false, nil
		}
	}

	if err := os.MkdirAll(dropInDir, 0755); err != nil {
		return false, fmt.Errorf("error creating %s dir: %v", dropInDir, err)
	}
	err := ioutil.WriteFile(filePath, []byte(config), 0644)
	log.Println("Written systemd service drop-in to disk.")
	return true, err
}
