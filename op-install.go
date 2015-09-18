package main

import (
	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

func install(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Printf("installing is deferred to the enable step to avoid timeouts.")
	return nil
}
