package main

import (
	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

func update(he vmextension.HandlerEnvironment, d driver.DistroDriver) error {
	log.Println("updating docker not implemented")
	return nil
}
