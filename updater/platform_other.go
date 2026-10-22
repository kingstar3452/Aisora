//go:build !darwin || !amd64

package main

import (
	"errors"
	"syscall"
)

func atomicExchange(a, b string) error { return errors.New("atomic installation requires Intel macOS") }
func nativeValidate(app string) error {
	return errors.New("native Apple signature and Gatekeeper validation unavailable on this platform")
}
func quarantine(app string) error { return errors.New("download quarantine requires macOS") }
func launchAndConfirm(app, data, token, version string) error {
	return errors.New("native launch unavailable")
}
func processAlive(pid int) bool { e := syscall.Kill(pid, 0); return e == nil || e == syscall.EPERM }
func reopenOriginal(app string) {}
func installPlatform() error {
	return errors.New("installation is supported only on Intel macOS Ventura or newer")
}
func usableBundlePath(app string) error { return installPlatform() }
func liveApplication(app string) bool   { return true }
