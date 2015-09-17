package main

import (
	"os"

	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

func uninstall(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Println("++ uninstall docker")
	if err := d.UninstallDocker(); err != nil {
		return err
	}
	log.Println("-- uninstall docker")

	log.Println("++ uninstall docker-compose")
	if err := uninstallDockerCompose(d); err != nil {
		return err
	}
	log.Println("++ uninstall docker-compose")
	return nil
}

func uninstallDockerCompose(d driver.DistroDriver) error {
	return os.RemoveAll(composeBinPath(d))
}
