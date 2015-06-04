package driver

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
)

// CoreOS: distro already comes with docker installed and
// uses systemd as init system.
type CoreOSDriver struct {
	systemdBaseDriver
}

func (c CoreOSDriver) InstallDocker() error {
	log.Println("CoreOS: docker already installed, noop")
	return nil
}
func (c CoreOSDriver) UninstallDocker() error {
	log.Println("CoreOS: docker cannot be uninstalled, noop")
	return nil
}

func (c CoreOSDriver) DockerComposeDir() string { return "/opt/bin" }

func (c CoreOSDriver) BaseOpts() []string { return []string{} }

func (c CoreOSDriver) ChangeOpts(args string) error {
	const dropInDir = "/run/systemd/system/docker.service.d"
	const dropInFile = "10-docker-extension.conf"

	data := []byte(fmt.Sprintf(`[Service]
Environment="DOCKER_OPTS=%s"`, args))

	if err := os.MkdirAll(dropInDir, 0755); err != nil {
		return fmt.Errorf("error creating %s dir: %v", dropInDir, err)
	}
	err := ioutil.WriteFile(filepath.Join(dropInDir, dropInFile), data, 0644)
	log.Println("Written systemd service drop-in to disk.")
	return err
}
