package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/util"
	"github.com/Azure/azure-docker-extension/pkg/executil"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

const (
	composeUrl = "https://github.com/docker/compose/releases/download/1.3.2/docker-compose-Linux-x86_64"
	composeBin = "docker-compose"
)

func install(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	// Install docker daemon
	log.Printf("++ install docker")
	if _, err := exec.LookPath("docker"); err == nil {
		log.Printf("docker already installed. not re-installing")
	} else {
		if err := d.InstallDocker(); err != nil {
			return err
		}
	}
	log.Printf("-- install docker")

	// Install docker-compose
	log.Printf("++ install docker-compose")
	if err := installCompose(d.DockerComposeDir()); err != nil {
		return fmt.Errorf("error installing docker-compose: %v", err)
	}
	log.Printf("-- install docker-compose")

	// Add user to 'docker' group to user docker as non-root
	u, err := util.GetAzureUser()
	if err != nil {
		return fmt.Errorf("failed to get provisioned user: %v", err)
	}
	log.Printf("++ add user to docker group")
	if out, err := executil.Exec("usermod", "-aG", "docker", u); err != nil {
		log.Printf("%s", string(out))
		return err
	}
	log.Printf("-- add user to docker group")

	return nil
}

// installCompose download docker-compose and saves to a predetermined path.
func installCompose(dir string) error {
	// Create dir if not exists
	ok, err := util.PathExists(dir)
	if err != nil {
		return err
	} else if !ok {
		if err := os.MkdirAll(dir, 755); err != nil {
			return err
		}
	}

	log.Printf("Downloading compose from %s", composeUrl)
	resp, err := http.Get(composeUrl)
	if err != nil {
		return fmt.Errorf("error downloading docker-compose: %v", err)
	}
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("response status code from %s: %s", composeUrl, resp.Status)
	}
	defer resp.Body.Close()

	fp := filepath.Join(dir, composeBin)
	f, err := os.OpenFile(fp, os.O_RDWR|os.O_CREATE, 0777)
	if err != nil {
		return fmt.Errorf("error creating %s: %v", fp, err)
	}

	defer f.Close()
	if _, err := io.Copy(f, resp.Body); err != nil {
		return fmt.Errorf("failed to save response body to %s: %v", fp, err)
	}
	return nil
}
