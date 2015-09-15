package main

import (
	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

func uninstall(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Println("++ uninstall docker")
	if err := d.UninstallDocker(); err != nil {
		return err
	}
	log.Println("-- uninstall docker")
	return nil
}
