package dockeropts

import (
	"testing"
)

func Test_SystemdUnitEditor_Bad(t *testing.T) {
	_, err := SystemdUnitEditor{}.ChangeOpts("FooBar", "--tlsverify")
	if err == nil {
		t.Fatal("error expected")
	}
}

func Test_SystemdUnitEditor(t *testing.T) {
	in := `[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket
Requires=docker.socket

[Service]
ExecStart=/usr/bin/docker -d -H fd://
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
`
	expected := `[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket
Requires=docker.socket

[Service]
ExecStart=/usr/bin/docker --tlsverify
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
`

	out, err := SystemdUnitEditor{}.ChangeOpts(in, "--tlsverify")
	if err != nil {
		t.Fatal(err)
	}
	if out != expected {
		t.Fatalf("out:%s\nexpected:%s", out, expected)
	}
}
