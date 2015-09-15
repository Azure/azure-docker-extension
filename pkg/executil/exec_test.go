package executil

import (
	"io/ioutil"
	"strings"
	"testing"
)

func Test_ExecOkProcess(t *testing.T) {
	out, err := Exec("date", `+%s`)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) == 0 {
		t.Fatal("empty output")
	}
}

func Test_ExecBadProcess(t *testing.T) {
	_, err := Exec("false")
	if err == nil {
		t.Fatal("expected error")
	}
	t.Logf("%v", err)
}

func Test_ExecWithStdin(t *testing.T) {
	s := "1\n2\n3"
	in := ioutil.NopCloser(strings.NewReader(s))
	b, err := ExecWithStdin(in, "cat")
	if err != nil {
		t.Fatal(err)
	}
	out := string(b)
	if out != s {
		t.Fatalf("got wrong string: %s, expected: %s", out, s)
	}
}
