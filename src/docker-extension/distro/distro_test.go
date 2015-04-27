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
