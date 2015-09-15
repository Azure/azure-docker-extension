package util

import (
	"os"
	"reflect"
	"testing"
)

func Test_ParseINI(t *testing.T) {
	cases := []struct {
		in  string
		out map[string]string
	}{
		{"", map[string]string{}},
		{"K=V\nFOO=BAR", map[string]string{"K": "V", "FOO": "BAR"}},
	}

	for _, c := range cases {
		m, err := ParseINI(c.in)
		if err != nil {
			t.Fatalf("config parsing failed for input: %q, err: %v", c.in, err)
		}
		if !reflect.DeepEqual(m, c.out) {
			t.Fatalf("got wrong output. expected: %v, got: %v", c.out, m)
		}
	}
}

func Test_ScriptDir(t *testing.T) {
	s, err := ScriptDir()
	if err != nil {
		t.Fatal(err)
	}
	if s == "" {
		t.Fatal("returned script dir is empty")
	}
	st, err := os.Stat(s)
	if err != nil {
		t.Fatal(err)
	}
	if !st.Mode().IsDir() {
		t.Fatalf("%s is not dir")
	}
	t.Logf("Script dir: %s", s)
}

func Test_GetAzureUser(t *testing.T) {
	u, err := GetAzureUser()
	if err != nil {
		if os.IsNotExist(err) {
			t.Skipf("File not found, maybe not running on Azure? %s", OvfEnvPath)
		}
		t.Fatal(err)
	}
	t.Log(u)
}

func Test_PathExists(t *testing.T) {
	for _, v := range []struct {
		path   string
		exists bool
	}{
		{".", true},
		{"/tmp", true},
		{"/tmp/foobar", false},
	} {
		ok, err := PathExists(v.path)
		if err != nil {
			t.Fatal(err)
		}
		if ok != v.exists {
			t.Fatal("got %v for %s, expected: %v", ok, v.path, v.exists)
		}
	}
}
