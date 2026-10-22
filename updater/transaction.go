package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// Both paths are siblings on the same filesystem. A native atomic exchange is
// mandatory; there is deliberately no delete-first or two-rename fallback.
type Transaction struct {
	Token           string `json:"token"`
	App             string `json:"app"`
	Candidate       string `json:"candidate"`
	Version         string `json:"version"`
	PreviousVersion string `json:"previous_version"`
	Phase           string `json:"phase"`
}

func writeJSON(path string, v any) error {
	b, e := json.MarshalIndent(v, "", "  ")
	if e != nil {
		return e
	}
	tmp := path + ".tmp"
	f, e := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if e != nil {
		return e
	}
	_, e = f.Write(append(b, '\n'))
	if e == nil {
		e = f.Sync()
	}
	ce := f.Close()
	if e != nil {
		return e
	}
	if ce != nil {
		return ce
	}
	if e = os.Rename(tmp, path); e != nil {
		return e
	}
	d, e := os.Open(filepath.Dir(path))
	if e != nil {
		return e
	}
	defer d.Close()
	return d.Sync()
}
func readJSON(path string, v any) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	st, e := f.Stat()
	if e != nil {
		return e
	}
	if st.Size() > 1<<20 {
		return errors.New("local update state too large")
	}
	return json.NewDecoder(f).Decode(v)
}
func (t Transaction) validatePaths() error {
	if !digestPattern.MatchString(t.Token) || filepath.Base(t.App) != "Aisora.app" || !filepath.IsAbs(t.App) || t.Candidate != filepath.Join(filepath.Dir(t.App), ".Aisora-update-"+t.Token+".app") {
		return errors.New("invalid local transaction paths")
	}
	if e := noSymlink(t.App); e != nil {
		return e
	}
	return noSymlink(t.Candidate)
}
func swapTransaction(t *Transaction, journal string, exchange func(string, string) error) error {
	if e := t.validatePaths(); e != nil {
		return e
	}
	t.Phase = "prepared"
	if e := writeJSON(journal, t); e != nil {
		return e
	}
	if e := exchange(t.App, t.Candidate); e != nil {
		return fmt.Errorf("atomic exchange refused; installed app untouched: %w", e)
	}
	t.Phase = "awaiting_health"
	if e := writeJSON(journal, t); e != nil {
		if restore := exchange(t.App, t.Candidate); restore != nil {
			return fmt.Errorf("journal failed (%v); rollback failed (%v); both bundles retained", e, restore)
		}
		return fmt.Errorf("journal failed; previous app restored: %w", e)
	}
	return nil
}
func restoreTransaction(t *Transaction, journal string, exchange func(string, string) error) error {
	if e := t.validatePaths(); e != nil {
		return e
	}
	// Infer exchange direction from actual bundle identity after an interrupted
	// journal write. A second retry must not swap the failed build back in.
	i, e := plistStrings(filepath.Join(t.App, "Contents/Info.plist"))
	if e != nil {
		return e
	}
	if i["AisoraVersion"] == t.PreviousVersion {
		t.Phase = "rolled_back"
		return writeJSON(journal, t)
	}
	if i["AisoraVersion"] != t.Version {
		return errors.New("installed version changed outside this transaction")
	}
	if e := validateBundle(t.Candidate, t.PreviousVersion); e != nil {
		return e
	}
	if e := exchange(t.App, t.Candidate); e != nil {
		return e
	}
	t.Phase = "rolled_back"
	return writeJSON(journal, t)
}
