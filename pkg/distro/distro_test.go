package distro

import (
	"testing"
)

func Test_GetDistro(t *testing.T) {
	d, err := GetDistro()
	if err != nil {
		t.Fatalf("failed to get distro: %v", err)
	}
	if d.Id == "" {
		t.Fatal("no distro id")
	}
	if d.Release == "" {
		t.Fatal("no distro release")
	}
	t.Logf("Distro: %#v", d)
}

func Test_lsbReleaseInfo_parse(t *testing.T) {
	s := []byte(`DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=14.04
DISTRIB_CODENAME=trusty
DISTRIB_DESCRIPTION="Ubuntu 14.04.3 LTS"`)
	i := lsbReleaseInfo{}
	d, err := i.parse(s)
	if err != nil {
		t.Fatal(err)
	}
	if d.Id != "Ubuntu" {
		t.Fatalf("wrong disro id: %s", d.Id)
	}
	if d.Release != "14.04" {
		t.Fatalf("wrong disro release: %s", d.Release)
	}
}

func Test_centosReleaseInfo_parseVersion(t *testing.T) {
	cases := []struct {
		in  string
		out string
	}{
		{"No version at all", ""},
		{"No minor version 3", ""},
		{"Should extract only numeric part 3.2a4.5", "3.2"},
		{"Should extract only first one    3.2 4.5", "3.2"},
		{"CentOS Linux release 7.1.1503 (Core)", "7.1.1503"},
		{"Red Hat Enterprise Linux Server release 7.2 (Maipo)", "7.2"},
		{"Foo 1.22.333.4444.55555", "1.22.333.4444.55555"},
	}

	i := centosReleaseInfo{}
	for _, c := range cases {
		v := i.parseVersion([]byte(c.in))
		if v != c.out {
			t.Fatalf("wrong version. expected=%q got=%q in=%q", c.out, v, c.in)
		}
	}
}
