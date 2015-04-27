// Package dockeropts provides various methods to modify docker
// service start arguments (a.k.a DOCKER_OPTS)
package dockeropts

// Editor describes an implementation that can
// take a init config for docker service and modify the start
// arguments and return the new init config contents.
type Editor interface {
	ChangeOpts(contents, args string) (out string, err error)
}
