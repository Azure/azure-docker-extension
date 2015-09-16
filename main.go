package main

import (
	"fmt"
	"io"
	"io/ioutil"
	lg "log"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"github.com/Azure/azure-docker-extension/pkg/distro"
	"github.com/Azure/azure-docker-extension/pkg/driver"
	"github.com/Azure/azure-docker-extension/pkg/executil"
	"github.com/Azure/azure-docker-extension/pkg/seqnumfile"
	"github.com/Azure/azure-docker-extension/pkg/status"
	"github.com/Azure/azure-docker-extension/pkg/util"
	"github.com/Azure/azure-docker-extension/pkg/vmextension"
)

const (
	HandlerEnv      = "HandlerEnvironment.json"
	HandlerManifest = "HandlerManifest.json"
	LogFilename     = "docker-extension.log"
)

var (
	log        *lg.Logger
	handlerEnv vmextension.HandlerEnvironment
	seqNum     = -1
	out        io.Writer
)

func init() {
	// Read extension handler environment
	var err error
	handlerEnv, err = parseHandlerEnv()
	if err != nil {
		lg.Fatalf("ERROR: Cannot load handler environment: %v", err)
	}
	seqNum, err = vmextension.FindSeqNum(handlerEnv.HandlerEnvironment.ConfigFolder)
	if err != nil {
		lg.Fatalf("ERROR: cannot find seqnum: %v", err)
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
	log.Printf("seqnum: %d", seqNum)

	// seqnum check: waagent invokes enable twice with the same seqnum, so exit the process
	// started later. Refuse proceeding if seqNum is smaller or the same than the one running.
	if seqExists, seq, err := seqnumfile.Get(); err != nil {
		log.Fatalf("ERROR: seqnumfile could not be read: %v", err)
	} else if seqExists {
		if seq == seqNum {
			log.Printf("WARNING: Another instance of the extension handler with the same seqnum (=%d) is currently active according to .seqnum file.", seq)
			log.Println("Exiting gracefully with exitcode 0, not reporting to .status file.")
			os.Exit(0)
		} else if seq > seqNum {
			log.Printf("WARNING: Another instance of the extension handler with a higher seqnum (%d > %d) is currently active according to .seqnum file. The smaller seqnum will not proceed.", seq, seqNum)
			log.Println("Exiting gracefully with exitcode 0, not reporting to .status file.")
			os.Exit(0)
		}
	}

	// create .seqnum file
	if err := seqnumfile.Set(seqNum); err != nil {
		log.Fatalf("Error seting seqnum file: %v", err)
	}

	var fail = func(format string, args ...interface{}) {
		logFail(op, fmt.Sprintf(format, args...))
	}

	// Report status as in progress
	if err := reportStatus(status.StatusTransitioning, op, ""); err != nil {
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
	reportStatus(status.StatusSuccess, op, "")

	// clear .seqnum file
	if err := seqnumfile.Delete(); err != nil {
		log.Printf("WARNING: Error deleting seqnumfile: %v", err)
	}
	log.Printf("Cleaned up .seqnum file.")
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

// reportStatus saves operation status to the status file for the extension.
func reportStatus(t status.Type, op Op, msg string) error {
	if !op.reportsStatus {
		log.Printf("Status '%s' not reported for operation '%v' (by design)", t, op.name)
		return nil
	}
	dir := handlerEnv.HandlerEnvironment.StatusFolder
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
	return s.Save(dir, seqNum)
}

// logFail prints the failure, reports failure status and exits
func logFail(op Op, msg string) {
	log.Printf(msg)
	if err := reportStatus(status.StatusError, op, msg); err != nil {
		log.Printf("Error reporting extension status: %v", err)
	}
	if err := seqnumfile.Delete(); err != nil {
		log.Printf("WARNING: Error deleting seqnumfile: %v", err)
	}
	log.Println("Cleaned up .seqnum file.")
	log.Println("Exiting with code 1.")
	os.Exit(1)
}
