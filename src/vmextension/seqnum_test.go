package vmextension

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func Test_FindSeqNum(t *testing.T) {
	cases := []struct {
		files []string
		out   int
		fails bool
	}{
		{[]string{}, 0, true},
		{[]string{"HandlerState", "0.settings"}, 0, false},
		{[]string{"HandlerState", "4.settings", "0.settings"}, 4, false},
		{[]string{"HandlerState", "0.settings", "1.settings", "12.settings", "2.settings"}, 12, false},
	}

	for i, c := range cases {
		td, err := ioutil.TempDir(os.TempDir(), fmt.Sprintf("test%d", i))
		if err != nil {
			t.Fatal(err)
		}
		defer os.RemoveAll(td)

		for _, f := range c.files {
			if _, err := os.Create(filepath.Join(td, f)); err != nil {
				t.Fatal(err)
			}
		}

		seq, err := FindSeqNum(td)
		if c.fails {
			if err == nil {
				t.Fatalf("expected to fail, didn't. case: %v", c.files)
			}
		} else {
			if err != nil {
				t.Fatalf("failed at case %v: %v", c, err)
			}
			if seq != c.out {
				t.Fatalf("wrong seqnum. expected:%d, got:%d. case: %v", c.out, seq, c.files)
			}
		}
	}
}
