package main

import (
	"executil"
	"fmt"
	"io"
	"io/ioutil"
	lg "log"
	"os"
	"os/user"
	"path/filepath"
	"strings"
	"vmextension"

	"docker-extension/distro"
	"docker-extension/driver"
	"docker-extension/status"
	"docker-extension/util"
)

const (
	HandlerEnv      = "HandlerEnvironment.json"
	HandlerManifest = "HandlerManifest.json"
	LogFilename     = "docker-extension.log"
)

var (
	log        *lg.Logger
	handlerEnv vmextension.HandlerEnvironment
	out        io.Writer
)

func init() {
	// Read extension handler environment
	var err error
	handlerEnv, err = parseHandlerEnv()
	if err != nil {
		lg.Fatalf("ERROR: Cannot load handler environment: %v", err)
	}

	// Update logger to write to logfile
	ld := handlerEnv.HandlerEnvironment.LogFolder
	if err := os.MkdirAll(ld, 0644); err != nil {
		lg.Fatalf("ERROR: Cannot create log folder %s: %v", ld, err)
	}
	lf, err := os.OpenFile(filepath.Join(ld, LogFilename), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		lg.Fatalf("ERROR: Cannot open log file: %v", err)
	}
	out = io.MultiWriter(os.Stderr, lf)
	log = lg.New(out, "[DockerExtension] ", lg.LstdFlags)
	executil.SetOut(out)
}

func main() {
	log.Printf(strings.Repeat("-", 40))
	log.Printf("Extension handler launch args: %#v", strings.Join(os.Args, " "))
	if len(os.Args) <= 1 {
		ops := []string{}
		for k, _ := range operations {
			ops = append(ops, k)
		}
		log.Fatalf("ERROR: No arguments supplied, valid arguments: '%s'.", strings.Join(ops, "', '"))
	}
	opStr := os.Args[1]
	op, ok := operations[opStr]
	if !ok {
		log.Fatalf("ERROR: Invalid operation provided: '%s'", opStr)
	}
	var fail = func(format string, args ...interface{}) {
		logFail(op, fmt.Sprintf(format, args...))
	}

	// Report status as in progress
	if err := reportStatus(handlerEnv, status.StatusTransitioning, op, ""); err != nil {
		log.Printf("Error reporting extension status: %v", err)
	}

	d, err := distro.GetDistro()
	if err != nil {
		fail("ERROR: Cannot get distro info: %v", err)
	}
	log.Printf("distro info: %s", d)
	dd, err := driver.GetDriver(d)
	if err != nil {
		fail("ERROR: %v", err)
	}
	log.Printf("using distro driver: %T", dd)

	if u, err := user.Current(); err != nil {
		log.Printf("Failed to get current user: %v", err)
	} else {
		log.Printf("user: %s uid:%v gid:%v", u.Username, u.Uid, u.Gid)
	}
	log.Printf("env['PATH'] = %s", os.Getenv("PATH"))

	log.Printf("+ starting: '%s'", opStr)
	if err = op.f(handlerEnv, dd); err != nil {
		fail("ERROR: %v", err)
	}
	log.Printf("- completed: '%s'", opStr)
	reportStatus(handlerEnv, status.StatusSuccess, op, "")
}

// parseHandlerEnv reads extension handler configuration from HandlerEnvironment.json file
func parseHandlerEnv() (vmextension.HandlerEnvironment, error) {
	var he vmextension.HandlerEnvironment
	dir, err := util.ScriptDir()
	if err != nil {
		return he, err
	}

	handlerEnvPath := filepath.Join(dir, "..", HandlerEnv)
	b, err := ioutil.ReadFile(handlerEnvPath)
	if err != nil {
		return he, fmt.Errorf("failed to read config: %v", err)
	}
	return vmextension.ParseHandlerEnv(b)
}

// reportStatus saves operation status to the status file
// for extension.
func reportStatus(he vmextension.HandlerEnvironment, t status.Type, op Op, msg string) error {
	if !op.reportsStatus {
		log.Printf("Status '%s' not reported for operation '%v' (by design)", t, op.name)
		return nil
	}
	seq, err := vmextension.FindSeqNum(he.HandlerEnvironment.ConfigFolder)
	if err != nil {
		log.Fatalf("ERROR: Cannot find seqnum: %v", err)
	}
	dir := he.HandlerEnvironment.StatusFolder
	m := msg
	if m == "" {
		m = op.name
		if t == status.StatusSuccess {
			m += " succeeded"
		}
	}
	if t == status.StatusError {
		m = fmt.Sprintf("%s failed: %s", op.name, m)
	}
	s := status.NewStatus(t, op.name, m)
	return s.Save(dir, seq)
}

// logFail prints the failure, reports failure status and exits
func logFail(op Op, msg string) {
	log.Printf(msg)
	if err := reportStatus(handlerEnv, status.StatusError, op, msg); err != nil {
		log.Printf("Error reporting extension status: %v", err)
	}
	os.Exit(1)
}
