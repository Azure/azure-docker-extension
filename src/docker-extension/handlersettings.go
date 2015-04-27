package main

import (
	"fmt"
	"vmextension"
)

// publicSettings is the type deserialized from public configuration section.
type publicSettings struct {
	Docker      dockerEngineSettings   `json:"docker"`
	ComposeJson map[string]interface{} `json:"compose"`
}

// protectedSettings is the type decoded and deserialized from protected
// configuration section.
type protectedSettings struct {
	Certs dockerCertSettings  `json:"certs"`
	Login dockerLoginSettings `json:"login"`
}

type dockerEngineSettings struct {
	Port    string   `json:"port"`
	Options []string `json:"options"`
}

type dockerLoginSettings struct {
	Server   string `json:"server"`
	Username string `json:"username"`
	Password string `json:"password"`
	Email    string `json:"email"`
}

type dockerCertSettings struct {
	CABase64         string `json:"ca"`
	ServerKeyBase64  string `json:"key"`
	ServerCertBase64 string `json:"cert"`
}

func (e dockerCertSettings) HasDockerCerts() bool {
	return e.CABase64 != "" && e.ServerKeyBase64 != "" && e.ServerCertBase64 != ""
}

func (e dockerLoginSettings) HasLoginInfo() bool {
	return e.Username != "" && e.Password != ""
}

type DockerHandlerSettings struct {
	publicSettings
	protectedSettings
}

func parseSettings(configFolder string) (*DockerHandlerSettings, error) {
	var pub publicSettings
	var prot protectedSettings

	if err := vmextension.UnmarshalHandlerSettings(configFolder, &pub, &prot); err != nil {
		return nil, fmt.Errorf("error parsing handler settings: %v", err)
	}
	return &DockerHandlerSettings{pub, prot}, nil
}
