// Aisora's bundled, unprivileged updater. No shell, downloaded scripts, cookies,
// credentials, privilege escalation, quarantine removal or security overrides.
package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var buildVersion = "6.1.0-rc.1"
var sourceCommit = "development"
var errUnconfirmed = errors.New("new application did not acknowledge health; it may still be running. Previous app retained. Close Aisora before using Restore Previous Version")

type Status struct {
	Source    string `json:"build_source"`
	Phase     string `json:"phase"`
	Message   string `json:"message"`
	Installed string `json:"installed"`
	Latest    string `json:"latest"`
	Tag       string `json:"tag"`
	Notes     string `json:"notes"`
	Path      string `json:"path"`
	Received  int64  `json:"received"`
	Total     int64  `json:"total"`
}
type Plan struct {
	Transaction Transaction `json:"transaction"`
	Manifest    Manifest    `json:"manifest"`
	Archive     string      `json:"archive"`
	TreeSHA     string      `json:"tree_sha256"`
}
type Options struct {
	Mode      string
	Data      string
	Tag       string
	Preview   bool
	Parent    int
	Bridge    string
	Confirmed bool
}

func bundledApp() (string, error) {
	p, e := os.Executable()
	if e != nil {
		return "", e
	}
	app := filepath.Dir(filepath.Dir(filepath.Dir(p)))
	if filepath.Base(app) != "Aisora.app" || filepath.Clean(p) != filepath.Join(app, "Contents/Helpers/AisoraUpdater") {
		return "", errors.New("run the helper bundled inside Aisora.app")
	}
	if e = noSymlink(app); e != nil {
		return "", e
	}
	info, e := plistStrings(filepath.Join(app, "Contents/Info.plist"))
	if e != nil {
		return "", e
	}
	if info["AisoraVersion"] != buildVersion {
		return "", errors.New("updater/app version mismatch")
	}
	return app, nil
}
func lock(data string) (func(), error) {
	p := filepath.Join(data, "job.lock")
	for i := 0; i < 2; i++ {
		if e := os.Mkdir(p, 0700); e == nil {
			if e = writeJSON(filepath.Join(p, "owner.json"), map[string]int{"pid": os.Getpid()}); e != nil {
				os.Remove(p)
				return nil, e
			}
			return func() { os.Remove(filepath.Join(p, "owner.json")); os.Remove(p) }, nil
		}
		var owner struct {
			PID int `json:"pid"`
		}
		if readJSON(filepath.Join(p, "owner.json"), &owner) != nil || owner.PID <= 1 {
			if st, err := os.Stat(p); err == nil && time.Since(st.ModTime()) > 2*time.Minute {
				os.Remove(filepath.Join(p, "owner.json"))
				if err = os.Remove(p); err == nil {
					continue
				}
			}
			return nil, errors.New("update lock is incomplete; close Aisora and retry after checking updates/job.lock")
		}
		if processAlive(owner.PID) {
			return nil, errors.New("another update task is running")
		}
		if e := os.Remove(filepath.Join(p, "owner.json")); e != nil {
			return nil, e
		}
		if e := os.Remove(p); e != nil {
			return nil, e
		}
	}
	return nil, errors.New("could not acquire update lock")
}
func voiceClear(path string, confirmed bool) error {
	if path == "" {
		if confirmed {
			return nil
		}
		return errors.New("confirm Voice has ended in the browser before restarting")
	}
	var pairing struct {
		Key  string `json:"key"`
		Port int    `json:"port"`
	}
	st, e := os.Stat(path)
	if e != nil || st.Size() > 2048 {
		return errors.New("bridge pairing unavailable; check Voice manually before retrying")
	}
	if e = readJSON(path, &pairing); e != nil || !digestPattern.MatchString(pairing.Key) || pairing.Port < 1024 || pairing.Port > 65535 {
		return errors.New("invalid local bridge pairing")
	}
	req, _ := http.NewRequest("GET", fmt.Sprintf("http://127.0.0.1:%d/v1/state", pairing.Port), nil)
	req.Header.Set("X-Aisora-Key", pairing.Key)
	client := &http.Client{Timeout: time.Second, Transport: &http.Transport{Proxy: nil}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	r, e := client.Do(req)
	if e != nil {
		if confirmed {
			return nil
		}
		return errors.New("bridge unreachable; confirm Voice ended manually")
	}
	defer r.Body.Close()
	if r.StatusCode != 200 {
		return errors.New("bridge authentication/state unavailable")
	}
	var state struct {
		Voice     string  `json:"voice"`
		Pending   bool    `json:"pending"`
		Capturing bool    `json:"capturing"`
		RMS       float64 `json:"rms"`
	}
	if e = json.NewDecoder(io.LimitReader(r.Body, 8192)).Decode(&state); e != nil {
		return e
	}
	if state.Voice == "active" || state.Pending || state.RMS > .012 {
		return errors.New("Voice/audio session is active; no update installed")
	}
	if state.Voice != "inactive" && !confirmed {
		return errors.New("Voice status is unknown; confirm it ended in the browser")
	}
	return nil
}
func treeDigest(root string) (string, error) {
	// Names, executable permissions and bytes must all survive the sibling copy.
	var records strings.Builder
	e := filepath.WalkDir(root, func(p string, d os.DirEntry, e error) error {
		if e != nil {
			return e
		}
		if d.IsDir() {
			return nil
		}
		if d.Type()&os.ModeSymlink != 0 {
			return errors.New("unexpected symlink")
		}
		r, e := filepath.Rel(root, p)
		if e != nil {
			return e
		}
		h, e := digestFile(p)
		if e != nil {
			return e
		}
		s, e := d.Info()
		if e != nil {
			return e
		}
		fmt.Fprintf(&records, "%s\x00%o\x00%s\n", r, s.Mode().Perm(), h)
		return nil
	})
	if e != nil {
		return "", e
	}
	b := []byte(records.String())
	return shaText(b), nil
}
func shaText(b []byte) string { // small local state only
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
func run(o Options, status func(Status) error) (result error) {
	if _, _, e := versionParts(buildVersion); e != nil {
		return e
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Minute)
	defer cancel()
	if o.Mode == "check" {
		var releases []Release
		if e := fetchJSON(ctx, "/releases?per_page=100", &releases); e != nil {
			return e
		}
		m, notes, e := selectLatest(releases, buildVersion, o.Preview)
		if e != nil {
			return e
		}
		if m.Version == "" {
			return status(Status{Phase: "current", Installed: buildVersion, Latest: buildVersion, Message: "No newer compatible published release in this channel. Legacy/source-only releases are skipped."})
		}
		return status(Status{Phase: "available", Installed: buildVersion, Latest: m.Version, Tag: m.Tag, Notes: notes, Message: "Update available. Download & Install stages it first; restarting requires separate confirmation and macOS approval."})
	}
	app, e := bundledApp()
	if e != nil {
		return e
	}
	if e = installPlatform(); e != nil {
		return e
	}
	if e = usableBundlePath(app); e != nil {
		return e
	}
	planPath := filepath.Join(o.Data, "plan.json")
	journal := filepath.Join(o.Data, "transaction.json")
	if o.Mode == "stage" {
		if e = voiceClear(o.Bridge, true); e != nil {
			return e
		}
		if !tagPattern.MatchString(o.Tag) {
			return errors.New("invalid release tag")
		}
		var r Release
		if e = fetchJSON(ctx, "/releases/tags/"+o.Tag, &r); e != nil {
			return e
		}
		m, e := releaseManifest(r, o.Preview)
		if e != nil {
			return e
		}
		c, e := compareVersion(m.Version, buildVersion)
		if e != nil || c <= 0 {
			return errors.New("release is not newer than this installed build")
		}
		folder := filepath.Join(o.Data, "downloads", m.Version)
		if e = os.MkdirAll(folder, 0700); e != nil {
			return e
		}
		archive := filepath.Join(folder, archiveName)
		h, _ := digestFile(archive)
		if h != m.SHA256 {
			os.Remove(archive + ".part")
			status(Status{Phase: "downloading", Latest: m.Version, Tag: m.Tag, Total: m.Bytes, Message: "Downloading to local staging; installed application is untouched."})
			if e = download(ctx, m, archive, func(n int64) {
				status(Status{Phase: "downloading", Latest: m.Version, Tag: m.Tag, Received: n, Total: m.Bytes, Message: "Downloading verified-release archive…"})
			}); e != nil {
				return e
			}
		}
		extracted := filepath.Join(folder, "unpacked")
		if e = os.RemoveAll(extracted); e != nil {
			return e
		}
		if e = unpack(archive, extracted); e != nil {
			return e
		}
		candidate := filepath.Join(extracted, "Aisora.app")
		status(Status{Phase: "validating", Latest: m.Version, Tag: m.Tag, Path: candidate, Message: "Checking structure, Apple signature and Gatekeeper policy…"})
		if e = validateBundle(candidate, m.Version); e != nil {
			return e
		}
		if e = quarantine(candidate); e != nil {
			return e
		}
		if e = nativeValidate(candidate); e != nil {
			status(Status{Phase: "blocked", Latest: m.Version, Tag: m.Tag, Path: candidate, Message: e.Error()})
			return nil
		}
		var nonce [32]byte
		if _, e = rand.Read(nonce[:]); e != nil {
			return e
		}
		token := hex.EncodeToString(nonce[:])
		sibling := filepath.Join(filepath.Dir(app), ".Aisora-update-"+token+".app")
		keep := false
		if _, err := os.Lstat(sibling); !os.IsNotExist(err) {
			return errors.New("staging destination already exists")
		}
		defer func() {
			if !keep {
				os.RemoveAll(sibling)
			}
		}()
		if e = copyTree(candidate, sibling); e != nil {
			return fmt.Errorf("cannot stage beside installed app; it is unchanged. Use a writable ~/Applications installation: %w", e)
		}
		if e = validateBundle(sibling, m.Version); e != nil {
			return e
		}
		if e = quarantine(sibling); e != nil {
			return e
		}
		if e = nativeValidate(sibling); e != nil {
			return e
		}
		h, e = treeDigest(candidate)
		if e != nil {
			return e
		}
		copyHash, e := treeDigest(sibling)
		if e != nil {
			return e
		}
		if copyHash != h {
			return errors.New("staging copy changed")
		}
		plan := Plan{Transaction: Transaction{Token: token, App: app, Candidate: sibling, Version: m.Version, PreviousVersion: buildVersion, Phase: "staged"}, Manifest: m, Archive: archive, TreeSHA: h}
		if e = writeJSON(planPath, plan); e != nil {
			return e
		}
		keep = true
		return status(Status{Phase: "ready", Latest: m.Version, Tag: m.Tag, Path: sibling, Message: "Fully staged and accepted by native checks. End Voice, then choose Restart to Update. Installed app remains untouched."})
	}
	if o.Mode != "install" && o.Mode != "rollback" {
		return errors.New("unknown updater mode")
	}
	if o.Parent <= 1 || o.Parent == os.Getpid() {
		return errors.New("invalid parent process")
	}
	if e = voiceClear(o.Bridge, o.Confirmed); e != nil {
		return e
	}
	status(Status{Phase: "waiting", Message: "Waiting for Aisora to close; Voice must remain stopped."})
	deadline := time.Now().Add(90 * time.Second)
	for processAlive(o.Parent) {
		if time.Now().After(deadline) {
			return errors.New("Aisora did not close; installed app unchanged")
		}
		time.Sleep(250 * time.Millisecond)
	}
	defer func() {
		// Reopen the unchanged original after a final preflight failure.
		if result != nil && !liveApplication(app) {
			info, err := plistStrings(filepath.Join(app, "Contents/Info.plist"))
			if err == nil && info["AisoraVersion"] == buildVersion {
				reopenOriginal(app)
			}
		}
	}()
	if liveApplication(app) {
		return errors.New("another Aisora instance is still running; installation refused")
	}
	if e = voiceClear(o.Bridge, o.Confirmed); e != nil {
		return e
	}
	if o.Mode == "rollback" {
		var t Transaction
		if e = readJSON(journal, &t); e != nil {
			return e
		}
		if t.App != app {
			return errors.New("rollback targets another installation")
		}
		if e = t.validatePaths(); e != nil {
			return e
		}
		if e = nativeValidate(t.Candidate); e != nil {
			return e
		}
		if e = restoreTransaction(&t, journal, atomicExchange); e != nil {
			return e
		}
		status(Status{Phase: "rolled_back", Message: "Previous application restored; local user data unchanged."})
		return launchAndConfirm(t.App, o.Data, t.Token, t.PreviousVersion)
	}
	var plan Plan
	if e = readJSON(planPath, &plan); e != nil {
		return e
	}
	t := &plan.Transaction
	if t.App != app || t.PreviousVersion != buildVersion || t.Version != plan.Manifest.Version {
		return errors.New("staged plan does not match this installed app")
	}
	if e = t.validatePaths(); e != nil {
		return e
	}
	if !strings.HasPrefix(plan.Archive, filepath.Join(o.Data, "downloads")+string(os.PathSeparator)) {
		return errors.New("archive outside local update cache")
	}
	if e = noSymlink(plan.Archive); e != nil {
		return e
	}
	h, e := digestFile(plan.Archive)
	if e != nil {
		return e
	}
	if h != plan.Manifest.SHA256 {
		return errors.New("cached archive changed; no installation performed")
	}
	if e = validateBundle(t.Candidate, t.Version); e != nil {
		return e
	}
	h, e = treeDigest(t.Candidate)
	if e != nil || h != plan.TreeSHA {
		return errors.New("staged bundle changed; no installation performed")
	}
	if e = nativeValidate(t.Candidate); e != nil {
		return e
	}
	if e = swapTransaction(t, journal, atomicExchange); e != nil {
		return e
	}
	status(Status{Phase: "restarting", Latest: t.Version, Message: "Replacement installed atomically; previous app retained. Waiting for startup health confirmation."})
	if e = launchAndConfirm(t.App, o.Data, t.Token, t.Version); e != nil {
		if errors.Is(e, errUnconfirmed) || liveApplication(app) {
			t.Phase = "unconfirmed"
			writeJSON(journal, t)
			return errUnconfirmed
		}
		if restore := restoreTransaction(t, journal, atomicExchange); restore != nil {
			return fmt.Errorf("launch failed (%v); restoration failed (%v). Both bundles retained", e, restore)
		}
		status(Status{Phase: "rolled_back", Message: "New app failed startup; previous app restored. User data unchanged."})
		return launchAndConfirm(t.App, o.Data, t.Token, t.PreviousVersion)
	}
	t.Phase = "complete"
	if e = writeJSON(journal, t); e != nil {
		return e
	}
	os.Remove(planPath)
	return status(Status{Phase: "complete", Installed: t.Version, Latest: t.Version, Path: t.Candidate, Message: "Update confirmed. Previous app retained as rollback copy; user data unchanged."})
}
func main() {
	var o Options
	flag.StringVar(&o.Mode, "mode", "check", "check, stage, install or rollback")
	flag.StringVar(&o.Data, "data", "", "private local updates directory")
	flag.StringVar(&o.Tag, "tag", "", "published release tag")
	flag.BoolVar(&o.Preview, "preview", false, "include prereleases")
	flag.IntVar(&o.Parent, "parent", 0, "Aisora process to wait for")
	flag.StringVar(&o.Bridge, "bridge", "", "local bridge pairing path")
	flag.BoolVar(&o.Confirmed, "confirmed-no-voice", false, "user confirmed external Voice ended")
	flag.Parse()
	if !filepath.IsAbs(o.Data) {
		fmt.Fprintln(os.Stderr, "absolute local updates directory required")
		os.Exit(2)
	}
	if e := noSymlink(o.Data); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(2)
	}
	if e := os.MkdirAll(o.Data, 0700); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(2)
	}
	unlock, e := lock(o.Data)
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
	defer unlock()
	status := func(s Status) error {
		s.Source = sourceCommit
		if s.Installed == "" {
			s.Installed = buildVersion
		}
		if len(s.Message) > 1800 {
			s.Message = s.Message[:1800]
		}
		return writeJSON(filepath.Join(o.Data, "status.json"), s)
	}
	status(Status{Phase: "starting", Message: "Preparing update task…"})
	if e = run(o, status); e != nil {
		status(Status{Phase: "error", Message: e.Error()})
		fmt.Fprintln(os.Stderr, e)
		unlock()
		os.Exit(1)
	}
}
