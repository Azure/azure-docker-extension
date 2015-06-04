package main

import (
	"docker-extension/driver"
	"vmextension"
)

func disable(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Printf("++ stop docker daemon")
	if err := d.StopDocker(); err != nil {
		return err
	}
	log.Printf("-- stop docker daemon")
	return nil
}
