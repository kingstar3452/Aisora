package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func manifestFixture() Manifest {
	return Manifest{Schema: 1, Version: "6.2.0", Tag: "v6.2.0", URL: "https://github.com/kingstar3452/Aisora/releases/download/v6.2.0/" + archiveName, SHA256: strings.Repeat("a", 64), Bytes: 20, Architecture: "x86_64", BundleID: "local.aisora.companion", MinMacOS: "13.0", Protocol: 1}
}
func releaseFixture(m Manifest) Release {
	b, _ := json.Marshal(m)
	return Release{Tag: m.Tag, Body: "Release notes\n" + manifestStart + string(b) + manifestEnd}
}
func TestSemanticVersionAndChannel(t *testing.T) {
	for _, pair := range [][2]string{{"6.1.0-rc.1", "6.1.0-rc.2"}, {"6.1.0-rc.9", "6.1.0-rc.10"}, {"6.1.0-rc.2", "6.1.0"}, {"6.9.0", "6.10.0"}} {
		if c, e := compareVersion(pair[0], pair[1]); e != nil || c >= 0 {
			t.Fatal(pair, c, e)
		}
	}
	for _, v := range []string{"6.1", "06.1.0", "6.1.0-rc..1", "6.1.0-01"} {
		if _, _, e := versionParts(v); e == nil {
			t.Fatal(v)
		}
	}
	m := manifestFixture()
	r := releaseFixture(m)
	r.Prerelease = true
	if _, e := releaseManifest(r, false); e == nil {
		t.Fatal("prerelease accepted without opt-in")
	}
	if _, e := releaseManifest(r, true); e != nil {
		t.Fatal(e)
	}
	r.Draft = true
	if _, e := releaseManifest(r, true); e == nil {
		t.Fatal("draft accepted")
	}
	old := m
	old.Version = "6.0.0"
	old.Tag = "v6.0.0"
	old.URL = strings.ReplaceAll(m.URL, "v6.2.0", old.Tag)
	latest, notes, e := selectLatest([]Release{releaseFixture(old), releaseFixture(m), {Tag: "legacy", Body: "source only"}}, "6.1.0", false)
	if e != nil || latest.Version != "6.2.0" || !strings.Contains(notes, "Release notes") {
		t.Fatal(latest, notes, e)
	}
	latest, _, e = selectLatest([]Release{releaseFixture(m)}, "6.3.0", false)
	if e != nil || latest.Version != "" {
		t.Fatal("downgrade", e)
	}
}
func TestRejectUnsafeManifest(t *testing.T) {
	for name, mutate := range map[string]func(*Manifest){"script URL": func(m *Manifest) { m.URL = "https://example.com/install.sh" }, "wrong repo": func(m *Manifest) { m.URL = strings.ReplaceAll(m.URL, repository, "attacker/other") }, "tag mismatch": func(m *Manifest) { m.Tag = "v6.3.0" }, "oversize": func(m *Manifest) { m.Bytes = maxArchive + 1 }, "bad sha": func(m *Manifest) { m.SHA256 = "trust me" }, "arm": func(m *Manifest) { m.Architecture = "arm64" }, "other bundle": func(m *Manifest) { m.BundleID = "other" }, "future protocol": func(m *Manifest) { m.Protocol = 2 }} {
		t.Run(name, func(t *testing.T) {
			m := manifestFixture()
			mutate(&m)
			if _, e := releaseManifest(releaseFixture(m), false); e == nil {
				t.Fatal("accepted")
			}
		})
	}
	for _, u := range []string{"http://github.com/kingstar3452/Aisora/releases/download/v1/" + archiveName, "https://github.com.evil.test/kingstar3452/Aisora/releases/download/v1/" + archiveName, "https://raw.githubusercontent.com/kingstar3452/Aisora/main/" + archiveName, "https://github.com/kingstar3452/Aisora/releases/download/v1/" + archiveName + "?script=1"} {
		if allowedDownload(u) {
			t.Fatal(u)
		}
	}
	if !allowedDownload("https://raw.githubusercontent.com/kingstar3452/Aisora/" + strings.Repeat("a", 40) + "/" + archiveName) {
		t.Fatal("immutable artifact refused")
	}
}
func TestZIPTraversalAndPermissions(t *testing.T) {
	for _, name := range []string{"../Aisora.app/Contents/x", "Aisora.app/../outside", "Aisora.app/Contents/../../bad", "/Aisora.app/x", "Aisora.app\\x", "evil.sh"} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			archive := filepath.Join(root, "bad.zip")
			f, _ := os.Create(archive)
			z := zip.NewWriter(f)
			w, _ := z.Create(name)
			w.Write([]byte("x"))
			z.Close()
			f.Close()
			if e := unpack(archive, filepath.Join(root, "stage")); e == nil {
				t.Fatal("accepted traversal")
			}
			if _, e := os.Stat(filepath.Join(root, "stage")); !os.IsNotExist(e) {
				t.Fatal("extracted before entry preflight")
			}
		})
	}
	for _, kind := range []string{"symlink", "duplicate", "noexecute"} {
		t.Run(kind, func(t *testing.T) {
			root := t.TempDir()
			archive := filepath.Join(root, "input.zip")
			f, _ := os.Create(archive)
			z := zip.NewWriter(f)
			h := &zip.FileHeader{Name: "Aisora.app/Contents/MacOS/Aisora"}
			h.SetMode(0644)
			if kind == "symlink" {
				h.SetMode(os.ModeSymlink | 0777)
			}
			w, _ := z.CreateHeader(h)
			w.Write([]byte("not code"))
			if kind == "duplicate" {
				second := *h
				w, e := z.CreateHeader(&second)
				if e != nil {
					t.Fatal(e)
				}
				w.Write([]byte("x"))
			}
			z.Close()
			f.Close()
			e := unpack(archive, filepath.Join(root, "out"))
			if kind == "noexecute" {
				if e != nil {
					t.Fatal(e)
				}
				if intelExecutable(filepath.Join(root, "out", h.Name)) == nil {
					t.Fatal("missing execute accepted")
				}
			} else if e == nil {
				t.Fatal("unsafe zip accepted")
			}
		})
	}
}
func tinyBundle(t *testing.T, path, version string) {
	t.Helper()
	for _, d := range []string{"Contents/MacOS", "Contents/Helpers", "Contents/Resources", "Contents/_CodeSignature"} {
		if e := os.MkdirAll(filepath.Join(path, d), 0755); e != nil {
			t.Fatal(e)
		}
	}
	info := `<?xml version="1.0"?><plist><dict><key>CFBundleIdentifier</key><string>local.aisora.companion</string><key>CFBundleExecutable</key><string>Aisora</string><key>AisoraVersion</key><string>` + version + `</string><key>AisoraUpdaterProtocol</key><string>1</string></dict></plist>`
	os.WriteFile(filepath.Join(path, "Contents/Info.plist"), []byte(info), 0644)
	var code bytes.Buffer
	binary.Write(&code, binary.LittleEndian, []uint32{0xfeedfacf, 0x01000007, 3, 2, 0, 0, 0, 0})
	for _, p := range []string{"Contents/MacOS/Aisora", "Contents/Helpers/AisoraUpdater"} {
		os.WriteFile(filepath.Join(path, p), code.Bytes(), 0755)
	}
	for _, p := range []string{"Contents/Resources/Aisora.pck", "Contents/Resources/Godot-NOTICES.txt", "Contents/_CodeSignature/CodeResources"} {
		os.WriteFile(filepath.Join(path, p), []byte(version), 0644)
	}
}
func fakeExchange(a, b string) error {
	temp := a + ".exchange"
	if e := os.Rename(a, temp); e != nil {
		return e
	}
	if e := os.Rename(b, a); e != nil {
		return e
	}
	return os.Rename(temp, b)
}
func TestTransactionRestoresAndIsIdempotent(t *testing.T) {
	root := t.TempDir()
	token := strings.Repeat("b", 64)
	app := filepath.Join(root, "Aisora.app")
	candidate := filepath.Join(root, ".Aisora-update-"+token+".app")
	tinyBundle(t, app, "6.1.0")
	tinyBundle(t, candidate, "6.2.0")
	tx := Transaction{Token: token, App: app, Candidate: candidate, Version: "6.2.0", PreviousVersion: "6.1.0"}
	journal := filepath.Join(root, "journal.json")
	if e := swapTransaction(&tx, journal, fakeExchange); e != nil {
		t.Fatal(e)
	}
	info, _ := plistStrings(filepath.Join(app, "Contents/Info.plist"))
	if info["AisoraVersion"] != "6.2.0" {
		t.Fatal(info)
	}
	if e := restoreTransaction(&tx, journal, fakeExchange); e != nil {
		t.Fatal(e)
	}
	if e := restoreTransaction(&tx, journal, fakeExchange); e != nil {
		t.Fatal("retry swapped failed app back", e)
	}
	info, _ = plistStrings(filepath.Join(app, "Contents/Info.plist"))
	if info["AisoraVersion"] != "6.1.0" {
		t.Fatal(info)
	}
}
func TestDeniedAtomicSwapLeavesOriginal(t *testing.T) {
	root := t.TempDir()
	token := strings.Repeat("c", 64)
	app := filepath.Join(root, "Aisora.app")
	candidate := filepath.Join(root, ".Aisora-update-"+token+".app")
	tinyBundle(t, app, "6.1.0")
	tinyBundle(t, candidate, "6.2.0")
	before, _ := treeDigest(app)
	tx := Transaction{Token: token, App: app, Candidate: candidate, Version: "6.2.0", PreviousVersion: "6.1.0"}
	if e := swapTransaction(&tx, filepath.Join(root, "journal.json"), func(string, string) error { return os.ErrPermission }); e == nil {
		t.Fatal("denied swap succeeded")
	}
	after, _ := treeDigest(app)
	if before != after {
		t.Fatal("working installation changed")
	}
}
func TestJournalFailureRestoresOriginal(t *testing.T) {
	root := t.TempDir()
	token := strings.Repeat("d", 64)
	app := filepath.Join(root, "Aisora.app")
	candidate := filepath.Join(root, ".Aisora-update-"+token+".app")
	tinyBundle(t, app, "6.1.0")
	tinyBundle(t, candidate, "6.2.0")
	before, _ := treeDigest(app)
	journal := filepath.Join(root, "journal.json")
	tx := Transaction{Token: token, App: app, Candidate: candidate, Version: "6.2.0", PreviousVersion: "6.1.0"}
	count := 0
	e := swapTransaction(&tx, journal, func(a, b string) error {
		count++
		if count == 1 {
			os.Mkdir(journal+".tmp", 0700)
		}
		return fakeExchange(a, b)
	})
	if e == nil || count != 2 {
		t.Fatal(e, count)
	}
	after, _ := treeDigest(app)
	if before != after {
		t.Fatal("journal failure did not restore original")
	}
}
func TestInterruptedJournalInfersRealVersions(t *testing.T) {
	root := t.TempDir()
	token := strings.Repeat("e", 64)
	tx := Transaction{Token: token, App: filepath.Join(root, "Aisora.app"), Candidate: filepath.Join(root, ".Aisora-update-"+token+".app"), Version: "6.2.0", PreviousVersion: "6.1.0", Phase: "prepared"}
	tinyBundle(t, tx.App, "6.2.0")
	tinyBundle(t, tx.Candidate, "6.1.0")
	if e := restoreTransaction(&tx, filepath.Join(root, "journal.json"), fakeExchange); e != nil {
		t.Fatal(e)
	}
	info, _ := plistStrings(filepath.Join(tx.App, "Contents/Info.plist"))
	if info["AisoraVersion"] != "6.1.0" {
		t.Fatal(info)
	}
}
func TestTreeAndStructureRejectChanges(t *testing.T) {
	root := t.TempDir()
	app := filepath.Join(root, "Aisora.app")
	tinyBundle(t, app, "6.2.0")
	if e := validateBundle(app, "6.2.0"); e != nil {
		t.Fatal(e)
	}
	if validateBundle(app, "6.3.0") == nil {
		t.Fatal("version mismatch accepted")
	}
	before, _ := treeDigest(app)
	os.WriteFile(filepath.Join(app, "Contents/Resources/Aisora.pck"), []byte("corrupt"), 0644)
	after, _ := treeDigest(app)
	if before == after {
		t.Fatal("changed pack not detected")
	}
	os.Symlink("/tmp", filepath.Join(app, "outside"))
	if validateBundle(app, "6.2.0") == nil {
		t.Fatal("symlink accepted")
	}
}
func TestVoiceGuard(t *testing.T) {
	state := `{"voice":"active","pending":false,"capturing":false}`
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Aisora-Key") != strings.Repeat("a", 64) {
			t.Error("pairing authentication missing")
		}
		w.Write([]byte(state))
	}))
	defer server.Close()
	port := strings.Split(server.URL, ":")[2]
	path := filepath.Join(t.TempDir(), "bridge.json")
	os.WriteFile(path, []byte(`{"key":"`+strings.Repeat("a", 64)+`","port":`+port+`}`), 0600)
	if voiceClear(path, true) == nil {
		t.Fatal("active Voice allowed even with manual confirmation")
	}
	state = `{"voice":"inactive","pending":true}`
	if voiceClear(path, true) == nil {
		t.Fatal("pending Voice allowed")
	}
	state = `{"voice":"inactive","capturing":false,"rms":0}`
	if e := voiceClear(path, false); e != nil {
		t.Fatal(e)
	}
	state = `{"voice":"inactive","capturing":true,"rms":0}`
	if e := voiceClear(path, false); e != nil {
		t.Fatal("silent tab capture must not be mistaken for an active Voice session", e)
	}
	if voiceClear("", false) == nil {
		t.Fatal("unobservable browser Voice not confirmed")
	}
}
func TestLockAndAtomicJSON(t *testing.T) {
	root := t.TempDir()
	unlock, e := lock(root)
	if e != nil {
		t.Fatal(e)
	}
	if _, e = lock(root); e == nil {
		t.Fatal("concurrent task allowed")
	}
	unlock()
	unlock, e = lock(root)
	if e != nil {
		t.Fatal(e)
	}
	unlock()
	p := filepath.Join(root, "state.json")
	if e = writeJSON(p, map[string]string{"phase": "ready"}); e != nil {
		t.Fatal(e)
	}
	var out map[string]string
	if e = readJSON(p, &out); e != nil || out["phase"] != "ready" {
		t.Fatal(out, e)
	}
}
func TestHTTPFailureDoesNotCreateDownload(t *testing.T) {
	// Cancellation exercises a failed download without talking to the Internet.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	p := filepath.Join(t.TempDir(), "archive.zip")
	if e := download(ctx, manifestFixture(), p, func(int64) {}); e == nil {
		t.Fatal("cancelled download passed")
	}
	if _, e := os.Stat(p); !os.IsNotExist(e) {
		t.Fatal("partial became finished archive")
	}
	if _, e := os.Stat(p + ".part"); !os.IsNotExist(e) {
		t.Fatal("partial not cleaned")
	}
}

// Fake transport returns bytes under a repository URL, so tests never weaken
// production URL checks, TLS validation or allowed redirect hosts.
type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestDownloadChecksumLengthAndInterruption(t *testing.T) {
	data := []byte("actual release archive")
	h := sha256.Sum256(data)
	for _, which := range []string{"valid", "wrong_hash", "short", "long", "http_error", "interrupted"} {
		t.Run(which, func(t *testing.T) {
			m := manifestFixture()
			m.Bytes = int64(len(data))
			m.SHA256 = hex.EncodeToString(h[:])
			payload := data
			code := 200
			switch which {
			case "wrong_hash":
				m.SHA256 = strings.Repeat("0", 64)
			case "short":
				payload = data[:4]
			case "long":
				payload = append(append([]byte{}, data...), 0)
			case "http_error":
				code = 403
			}
			client := &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
				if which == "interrupted" {
					return nil, errors.New("connection lost")
				}
				return &http.Response{StatusCode: code, ContentLength: -1, Body: io.NopCloser(bytes.NewReader(payload))}, nil
			})}
			path := filepath.Join(t.TempDir(), "download.zip")
			e := downloadUsing(context.Background(), client, m, path, func(int64) {})
			if which == "valid" {
				if e != nil {
					t.Fatal(e)
				}
				out, _ := os.ReadFile(path)
				if !bytes.Equal(out, data) {
					t.Fatal("wrong bytes")
				}
			} else {
				if e == nil {
					t.Fatal("invalid download passed")
				}
				if _, e := os.Stat(path); !os.IsNotExist(e) {
					t.Fatal("bad download committed")
				}
			}
			if _, e := os.Stat(path + ".part"); !os.IsNotExist(e) {
				t.Fatal("partial not cleaned")
			}
		})
	}
}
