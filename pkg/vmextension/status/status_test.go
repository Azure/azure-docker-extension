package status

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func Test_NewStatus(t *testing.T) {
	dir, err := ioutil.TempDir("", "")
	defer os.RemoveAll(dir)
	if err != nil {
		t.Fatal(err)
	}

	s := NewStatus(StatusSuccess, "op", "msg")
	if err := s.Save(dir, 2); err != nil {
		t.Fatal(err)
	}

	out, err := ioutil.ReadFile(filepath.Join(dir, "2.status"))
	if err != nil {
		t.Fatal(err)
	}

	if len(out) == 0 {
		t.Fatal("file empty")
	}
}
