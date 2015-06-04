package main

import (
	"vmextension"

	"docker-extension/driver"
)

func uninstall(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Println("++ uninstall docker")
	if err := d.UninstallDocker(); err != nil {
		return err
	}
	log.Println("-- uninstall docker")
	return nil
}
