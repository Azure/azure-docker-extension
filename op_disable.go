package main

import (
	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

func disable(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Printf("++ stop docker daemon")
	if err := d.StopDocker(); err != nil {
		return err
	}
	log.Printf("-- stop docker daemon")
	return nil
}
