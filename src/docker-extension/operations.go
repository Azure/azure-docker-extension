package main

import (
	"docker-extension/driver"
	"vmextension"
)

type OperationFunc func(vmextension.HandlerEnvironment, driver.DistroDriver) error

type Op struct {
	f             OperationFunc
	name          string
	reportsStatus bool // determines if op should log to .status file
}

var operations = map[string]Op{
	"install":   Op{install, "Install Docker", false},
	"uninstall": Op{uninstall, "Uninstall Docker", false},
	"enable":    Op{enable, "Enable Docker", true},
	"update":    Op{update, "Updating Docker", true},
	"disable":   Op{disable, "Disabling Docker", true},
}
