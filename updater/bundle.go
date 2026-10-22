package main

import (
	"archive/zip"
	"crypto/sha256"
	"debug/macho"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func digestFile(path string) (string, error) {
	f, e := os.Open(path)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
func noSymlink(path string) error {
	p, e := filepath.Abs(path)
	if e != nil {
		return e
	}
	for {
		info, e := os.Lstat(p)
		if e == nil && info.Mode()&os.ModeSymlink != 0 {
			return errors.New("symbolic-link paths are not supported")
		}
		if e != nil && !os.IsNotExist(e) {
			return e
		}
		next := filepath.Dir(p)
		if next == p {
			break
		}
		p = next
	}
	return nil
}
func unpack(archive, destination string) error {
	z, e := zip.OpenReader(archive)
	if e != nil {
		return e
	}
	defer z.Close()
	if len(z.File) > 2048 {
		return errors.New("unexpected archive entry count")
	}
	seen := map[string]bool{}
	var total uint64
	for _, f := range z.File {
		name := strings.TrimSuffix(f.Name, "/")
		if seen[name] || name == "" || strings.Contains(f.Name, "\\") || strings.Contains(f.Name, "\x00") || !strings.HasPrefix(f.Name, "Aisora.app/") || filepath.ToSlash(filepath.Clean(name)) != name || filepath.IsAbs(name) {
			return errors.New("unsafe, duplicate or unexpected archive path")
		}
		seen[name] = true
		if f.Mode()&os.ModeSymlink != 0 || (!f.Mode().IsRegular() && !f.FileInfo().IsDir()) {
			return errors.New("archive contains a symbolic link or special file")
		}
		if f.UncompressedSize64 > 512<<20 || total > 512<<20-f.UncompressedSize64 {
			return errors.New("expanded archive exceeds budget")
		}
		total += f.UncompressedSize64
	}
	if e = os.Mkdir(destination, 0700); e != nil {
		return e
	}
	for _, f := range z.File {
		p := filepath.Join(destination, filepath.FromSlash(f.Name))
		if f.FileInfo().IsDir() {
			if e = os.MkdirAll(p, 0755); e != nil {
				return e
			}
			continue
		}
		if e = os.MkdirAll(filepath.Dir(p), 0755); e != nil {
			return e
		}
		r, e := f.Open()
		if e != nil {
			return e
		}
		w, e := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, f.Mode().Perm()&0777)
		if e != nil {
			r.Close()
			return e
		}
		n, copyErr := io.Copy(w, io.LimitReader(r, int64(f.UncompressedSize64)+1))
		closeErr := w.Close()
		r.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		if n != int64(f.UncompressedSize64) {
			return errors.New("expanded length mismatch")
		}
	}
	return nil
}
func plistStrings(path string) (map[string]string, error) {
	f, e := os.Open(path)
	if e != nil {
		return nil, e
	}
	defer f.Close()
	d := xml.NewDecoder(io.LimitReader(f, 128<<10))
	values := map[string]string{}
	var key string
	for {
		t, e := d.Token()
		if e == io.EOF {
			break
		}
		if e != nil {
			return nil, e
		}
		start, ok := t.(xml.StartElement)
		if !ok {
			continue
		}
		if start.Name.Local == "key" {
			if e = d.DecodeElement(&key, &start); e != nil {
				return nil, e
			}
		} else if start.Name.Local == "string" && key != "" {
			var s string
			if e = d.DecodeElement(&s, &start); e != nil {
				return nil, e
			}
			values[key] = s
			key = ""
		}
	}
	return values, nil
}
func intelExecutable(path string) error {
	st, e := os.Stat(path)
	if e != nil {
		return e
	}
	if !st.Mode().IsRegular() || st.Mode().Perm()&0111 == 0 {
		return errors.New("executable permission missing")
	}
	f, e := macho.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	if f.Cpu != macho.CpuAmd64 || f.Type != macho.TypeExec {
		return errors.New("expected thin Intel x86_64 executable")
	}
	return nil
}
func validateBundle(app, version string) error {
	if e := noSymlink(app); e != nil {
		return e
	}
	info, e := plistStrings(filepath.Join(app, "Contents/Info.plist"))
	if e != nil {
		return e
	}
	if info["CFBundleIdentifier"] != "local.aisora.companion" || info["CFBundleExecutable"] != "Aisora" || info["AisoraVersion"] != version || info["AisoraUpdaterProtocol"] != "1" {
		return errors.New("application identity, version or updater protocol mismatch")
	}
	for _, name := range []string{"Contents/MacOS/Aisora", "Contents/Helpers/AisoraUpdater"} {
		if e = intelExecutable(filepath.Join(app, name)); e != nil {
			return fmt.Errorf("%s: %w", name, e)
		}
	}
	for _, name := range []string{"Contents/Resources/Aisora.pck", "Contents/_CodeSignature/CodeResources", "Contents/Resources/Godot-NOTICES.txt"} {
		st, e := os.Stat(filepath.Join(app, name))
		if e != nil || !st.Mode().IsRegular() || st.Size() == 0 {
			return fmt.Errorf("missing/empty required bundled resource: %s", name)
		}
	}
	return filepath.WalkDir(app, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&os.ModeSymlink != 0 {
			return errors.New("bundle contains symlink")
		}
		if !d.IsDir() {
			st, e := d.Info()
			if e != nil {
				return e
			}
			if !st.Mode().IsRegular() {
				return errors.New("bundle contains special file")
			}
		}
		return nil
	})
}
func copyTree(from, to string) error {
	if e := os.Mkdir(to, 0755); e != nil {
		return e
	}
	return filepath.WalkDir(from, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if p == from {
			return nil
		}
		rel, e := filepath.Rel(from, p)
		if e != nil {
			return e
		}
		target := filepath.Join(to, rel)
		st, e := d.Info()
		if e != nil {
			return e
		}
		if st.Mode()&os.ModeSymlink != 0 {
			return errors.New("refusing symlink copy")
		}
		if d.IsDir() {
			return os.Mkdir(target, st.Mode().Perm())
		}
		if !st.Mode().IsRegular() {
			return errors.New("refusing special file")
		}
		r, e := os.Open(p)
		if e != nil {
			return e
		}
		defer r.Close()
		w, e := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, st.Mode().Perm())
		if e != nil {
			return e
		}
		_, e = io.Copy(w, r)
		if e == nil {
			e = w.Sync()
		}
		ce := w.Close()
		if e != nil {
			return e
		}
		return ce
	})
}
