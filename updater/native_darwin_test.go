//go:build darwin && amd64

package main

import (
	"os"
	"path/filepath"
	"testing"
)

// Exercise the real XNU exchange syscall on temporary directories, separately
// from injected transaction fixtures. No installed application is involved.
func TestDarwinNativeDirectoryExchange(t *testing.T) {
	dir := t.TempDir()
	a, b := filepath.Join(dir, "first.app"), filepath.Join(dir, "second.app")
	for path, value := range map[string]string{a: "first", b: "second"} {
		if err := os.Mkdir(path, 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(path, "marker"), []byte(value), 0600); err != nil {
			t.Fatal(err)
		}
	}
	read := func(path string) string {
		value, err := os.ReadFile(filepath.Join(path, "marker"))
		if err != nil {
			t.Fatal(err)
		}
		return string(value)
	}
	if err := atomicExchange(a, b); err != nil {
		t.Fatal(err)
	}
	if read(a) != "second" || read(b) != "first" {
		t.Fatal("Native exchange did not swap directory contents")
	}
	if err := atomicExchange(a, b); err != nil {
		t.Fatal(err)
	}
	if read(a) != "first" || read(b) != "second" {
		t.Fatal("Native exchange could not restore original contents")
	}
	if err := atomicExchange(a, filepath.Join(dir, "missing.app")); err == nil {
		t.Fatal("Missing exchange target accepted")
	}
	if read(a) != "first" {
		t.Fatal("Failed exchange changed original data")
	}
}
