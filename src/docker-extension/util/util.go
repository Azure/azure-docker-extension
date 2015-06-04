package util

import (
	"bufio"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

const (
	OvfEnvPath = "/var/lib/waagent/ovf-env.xml"
)

// ParseINI basic INI config file format into a map.
// Example expected format:
//     KEY=VAL
//     KEY2=VAL2
func ParseINI(s string) (map[string]string, error) {
	m := make(map[string]string)
	sc := bufio.NewScanner(strings.NewReader(s))

	for sc.Scan() {
		l := sc.Text() // format: K=V
		p := strings.Split(l, "=")
		if len(p) != 2 {
			return nil, fmt.Errorf("Unexpected config line: %q", l)
		}
		m[p[0]] = p[1]
	}
	if err := sc.Err(); err != nil {
		return nil, fmt.Errorf("Could not scan config file: %v", err)
	}
	return m, nil
}

// ScriptDir returns the absolute path of the running process.
func ScriptDir() (string, error) {
	p, err := filepath.Abs(os.Args[0])
	if err != nil {
		return "", err
	}
	return filepath.Dir(p), nil
}

// GetAzureUser returns the username provided at VM provisioning time to Azure.
func GetAzureUser() (string, error) {
	b, err := ioutil.ReadFile(OvfEnvPath)
	if err != nil {
		return "", err
	}

	var v struct {
		XMLName  xml.Name `xml:"Environment"`
		UserName string   `xml:"ProvisioningSection>LinuxProvisioningConfigurationSet>UserName"`
	}
	if err := xml.Unmarshal(b, &v); err != nil {
		return "", err
	}
	return v.UserName, nil
}

// PathExists checks if a path is a directory or file on the
// filesystem.
func PathExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}
