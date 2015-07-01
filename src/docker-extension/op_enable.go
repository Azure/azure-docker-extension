package main

import (
	"docker-extension/driver"
	"docker-extension/util"
	"encoding/base64"
	"executil"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"
	"vmextension"

	"gopkg.in/yaml.v2"
)

const (
	composeDir     = "/etc/docker/compose"
	composeYml     = "docker-compose.yml"
	composeProject = "compose" // prefix for compose-created containers

	dockerCfgDir  = "/etc/docker"
	dockerCaCert  = "ca.pem"
	dockerSrvCert = "cert.pem"
	dockerSrvKey  = "key.pem"
)

func enable(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	settings, err := parseSettings(he.HandlerEnvironment.ConfigFolder)
	if err != nil {
		return err
	}

	// Install docker remote access certs
	log.Printf("++ setup docker certs")
	if err := installDockerCerts(*settings, dockerCfgDir); err != nil {
		return fmt.Errorf("error installing docker certs: %v", err)
	}
	log.Printf("-- setup docker certs")

	// Update dockeropts
	log.Printf("++ update dockeropts")
	if err := updateDockerOpts(d, getArgs(*settings, d)); err != nil {
		return fmt.Errorf("failed to update dockeropts: %v", err)
	}
	log.Printf("-- update dockeropts")

	// Restart docker
	log.Printf("++ restart docker")
	if err := d.RestartDocker(); err != nil {
		return err
	}
	time.Sleep(3 * time.Second) // wait for instance to come up
	log.Printf("-- restart docker")

	// Login Docker registry server
	log.Printf("++ login docker registry")
	if err := loginRegistry(settings.Login); err != nil {
		return err
	}
	log.Printf("-- login docker registry")

	// Compose Up
	log.Printf("++ compose up")
	if err := composeUp(d, settings.ComposeJson); err != nil {
		return fmt.Errorf("'compose up' failed: %v", err)
	}
	log.Printf("-- compose up")
	return nil
}

func loginRegistry(s dockerLoginSettings) error {
	if !s.HasLoginInfo() {
		log.Println("registry login not specificied")
		return nil
	}
	opts := []string{
		"login",
		"--email=" + s.Email,
		"--username=" + s.Username,
		"--password=" + s.Password,
	}
	if s.Server != "" {
		opts = append(opts, s.Server)
	}
	return executil.ExecPipe("docker", opts...)
}

func composeUp(d driver.DistroDriver, json map[string]interface{}) error {
	if len(json) == 0 {
		log.Println("docker-compose config not specified, noop")
		return nil
	}

	// Convert json to yaml
	yaml, err := yaml.Marshal(json)
	if err != nil {
		return fmt.Errorf("error converting to compose.yml: %v", err)
	}

	if err := os.MkdirAll(composeDir, 0777); err != nil {
		return fmt.Errorf("failed creating %s: %v", composeDir, err)
	}
	log.Printf("Using compose yaml:>>>>>\n%s\n<<<<<", string(yaml))
	ymlPath := filepath.Join(composeDir, composeYml)
	if err := ioutil.WriteFile(ymlPath, yaml, 0666); err != nil {
		return fmt.Errorf("error writing %s: %v", ymlPath, err)
	}

	compose := filepath.Join(d.DockerComposeDir(), composeBin)
	return executil.ExecPipe(compose, "-p", composeProject, "-f", ymlPath, "up", "-d")
}

// installDockerCerts saves the configured certs to the specified dir
// if and only if the certs are not already placed there. If no certs
// are provided  or some certs already exist, nothing is written.
func installDockerCerts(s DockerHandlerSettings, dstDir string) error {
	m := []struct {
		src string
		dst string
	}{
		{s.Certs.CABase64, filepath.Join(dstDir, dockerCaCert)},
		{s.Certs.ServerCertBase64, filepath.Join(dstDir, dockerSrvCert)},
		{s.Certs.ServerKeyBase64, filepath.Join(dstDir, dockerSrvKey)},
	}

	// Check if certs are provided
	for _, v := range m {
		if len(v.src) == 0 {
			log.Printf("Docker certificate %s is not provided in the extension settings, skipping docker certs installation", v.dst)
			return nil
		}
	}

	// Check the target directory, if not create
	if ok, err := util.PathExists(dstDir); err != nil {
		return fmt.Errorf("error checking cert dir: %v", err)
	} else if !ok {
		if err := os.MkdirAll(dstDir, 0755); err != nil {
			return err
		}
	}

	// Write the certs
	for _, v := range m {
		// Decode base64
		in := strings.TrimSpace(v.src)
		f, err := base64.StdEncoding.DecodeString(in)
		if err != nil {
			// Fallback to original file input
			f = []byte(in)
		}

		if err := ioutil.WriteFile(v.dst, f, 0600); err != nil {
			return fmt.Errorf("error writing certificate: %v", err)
		}
	}
	return nil
}

func updateDockerOpts(dd driver.DistroDriver, args string) error {
	log.Printf("Updating daemon args to: %s", args)
	if err := dd.ChangeOpts(args); err != nil {
		return fmt.Errorf("error updating DOCKER_OPTS: %v", err)
	}
	return nil
}

func getArgs(s DockerHandlerSettings, dd driver.DistroDriver) string {
	args := dd.BaseOpts()

	if s.Certs.HasDockerCerts() {
		tls := []string{"--tlsverify",
			fmt.Sprintf("--tlscacert=%s", filepath.Join(dockerCfgDir, dockerCaCert)),
			fmt.Sprintf("--tlscert=%s", filepath.Join(dockerCfgDir, dockerSrvCert)),
			fmt.Sprintf("--tlskey=%s", filepath.Join(dockerCfgDir, dockerSrvKey)),
		}
		args = append(args, tls...)
	}

	if s.Docker.Port != "" {
		args = append(args, fmt.Sprintf("-H=0.0.0.0:%s", s.Docker.Port))
	}

	if len(s.Docker.Options) > 0 {
		args = append(args, s.Docker.Options...)
	}

	return strings.Join(args, " ")
}
