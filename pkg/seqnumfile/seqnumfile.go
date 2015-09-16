// Package seqnumfile contains helper methods that allow saving
// and retrieving extension handler seqNum from a hard-coded file
// path. Atomicity requirements are relaxed, therefore files are used.
package seqnumfile

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
)

const (
	filename = "docker-extension.seqnum"
)

func Get() (exists bool, seqnum int, err error) {
	b, err := ioutil.ReadFile(filePath())
	if err != nil {
		if os.IsNotExist(err) {
			return false, 0, nil
		}
		return false, 0, err
	}
	n, err := strconv.Atoi(string(b))
	if err != nil {
		return true, 0, fmt.Errorf("seqnumfile: cannot atoi %q: %v", b, err)
	}
	return true, n, nil
}

func Set(seqnum int) error {
	return ioutil.WriteFile(filePath(), []byte(fmt.Sprintf("%d", seqnum)), 0644)
}

func Delete() error {
	return os.RemoveAll(filePath())
}

func filePath() string {
	return filepath.Join(os.TempDir(), filename)
}
