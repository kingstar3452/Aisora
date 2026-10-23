//go:build darwin && amd64

package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

func atomicExchange(a, b string) error {
	// XNU renameatx_np(AT_FDCWD, a, AT_FDCWD, b, RENAME_SWAP).
	// macOS 13 Intel supports this atomic same-volume directory exchange. There
	// is no interval in which Aisora.app is missing, even if the process dies.
	x, e := syscall.BytePtrFromString(a)
	if e != nil {
		return e
	}
	y, e := syscall.BytePtrFromString(b)
	if e != nil {
		return e
	}
	_, _, errno := syscall.Syscall6(488, ^uintptr(1), uintptr(unsafe.Pointer(x)), ^uintptr(1), uintptr(unsafe.Pointer(y)), 2, 0)
	if errno != 0 {
		return errno
	}
	return nil
}
func nativeValidate(app string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if b, e := exec.CommandContext(ctx, "/usr/bin/codesign", "--verify", "--deep", "--strict", app).CombinedOutput(); e != nil {
		return fmt.Errorf("Apple codesign rejected staged app: %s", strings.TrimSpace(string(b)))
	}
	if b, e := exec.CommandContext(ctx, "/usr/sbin/spctl", "--assess", "--type", "execute", "--verbose=2", app).CombinedOutput(); e != nil {
		return fmt.Errorf("Gatekeeper has not accepted this update; installation blocked. Ad-hoc signing is not notarization. Use normal macOS approval only if offered. %s", strings.TrimSpace(string(b)))
	}
	return nil
}
func quarantine(app string) error {
	// Our downloader is responsible for marking Internet content. Never clear
	// quarantine, disable assessments, or grant ourselves an exception.
	value := "0083;" + strconv.FormatInt(time.Now().Unix(), 16) + ";AisoraUpdater;"
	for _, p := range []string{app, filepath.Join(app, "Contents/MacOS/Aisora"), filepath.Join(app, "Contents/Helpers/AisoraUpdater")} {
		if b, e := exec.Command("/usr/bin/xattr", "-w", "com.apple.quarantine", value, p).CombinedOutput(); e != nil {
			return fmt.Errorf("could not preserve download quarantine: %s", b)
		}
	}
	return nil
}
func launchAndConfirm(app, data, token, version string) error {
	cmd := exec.Command("/usr/bin/open", "-n", "-W", app, "--args", "--", "--aisora-update-token="+token)
	if e := cmd.Start(); e != nil {
		return e
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	deadline := time.After(100 * time.Second)
	for {
		select {
		case <-ticker.C:
			var h struct {
				Token   string `json:"token"`
				Version string `json:"version"`
			}
			if readJSON(filepath.Join(data, "healthy.json"), &h) == nil && h.Token == token && h.Version == version {
				return nil
			}
		case e := <-done:
			if e != nil {
				return fmt.Errorf("launch failed: %w", e)
			}
			return errors.New("application closed before its health acknowledgement")
		case <-deadline:
			// The new app may still be running. Never replace it under a live process.
			return errUnconfirmed
		}
	}
}
func processAlive(pid int) bool { e := syscall.Kill(pid, 0); return e == nil || e == syscall.EPERM }
func reopenOriginal(app string) { exec.Command("/usr/bin/open", "-n", app).Run() }
func installPlatform() error {
	b, e := exec.Command("/usr/bin/sw_vers", "-productVersion").Output()
	if e != nil {
		return e
	}
	major, e := strconv.Atoi(strings.Split(strings.TrimSpace(string(b)), ".")[0])
	if e != nil || major < 13 {
		return errors.New("updater requires macOS Ventura 13 or newer")
	}
	return nil
}
func liveApplication(app string) bool {
	// Only used on launch failure: inspect executable paths, without killing
	// processes or assuming open(1)'s PID is the application PID.
	b, e := exec.Command("/bin/ps", "-axww", "-o", "comm=").Output()
	if e != nil {
		return true
	}
	wanted := filepath.Join(app, "Contents/MacOS/Aisora")
	for _, line := range strings.Split(string(b), "\n") {
		name := strings.TrimSpace(line)
		if name == wanted || name == "Aisora" || strings.HasSuffix(name, "/Aisora.app/Contents/MacOS/Aisora") {
			return true
		}
	}
	return false
}
func usableBundlePath(app string) error {
	if strings.Contains(app, "/AppTranslocation/") || strings.HasPrefix(app, "/Volumes/") {
		return errors.New("move Aisora.app to ~/Applications or a writable Applications folder before updating")
	}
	if os.Geteuid() == 0 {
		return errors.New("do not run the updater as root")
	}
	return nil
}
