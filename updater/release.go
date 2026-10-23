package main

// Release data is inert JSON obtained only from this repository over HTTPS.
// Checksums detect damage; repository access + HTTPS, not the checksum alone,
// are the source of provenance. Apple's trust assessment is a separate gate.
import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const repository = "kingstar3452/Aisora"
const apiRoot = "https://api.github.com/repos/" + repository
const archiveName = "Aisora-phase6-macos.zip"
const manifestStart = "<!-- AISORA_UPDATE_V1\n"
const manifestEnd = "\nAISORA_UPDATE_V1 -->"
const maxArchive = 200 << 20

var versionPattern = regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?$`)
var digestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
var tagPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$`)

type Manifest struct {
	Schema       int    `json:"schema"`
	Version      string `json:"version"`
	Tag          string `json:"tag"`
	URL          string `json:"url"`
	SHA256       string `json:"sha256"`
	Bytes        int64  `json:"bytes"`
	Architecture string `json:"architecture"`
	BundleID     string `json:"bundle_id"`
	MinMacOS     string `json:"min_macos"`
	Protocol     int    `json:"updater_protocol"`
}
type Release struct {
	Tag        string `json:"tag_name"`
	Body       string `json:"body"`
	Draft      bool   `json:"draft"`
	Prerelease bool   `json:"prerelease"`
}

func versionParts(v string) ([]int, []string, error) {
	m := versionPattern.FindStringSubmatch(v)
	if m == nil {
		return nil, nil, errors.New("invalid semantic version")
	}
	n := make([]int, 3)
	for i := 0; i < 3; i++ {
		a, e := strconv.Atoi(m[i+1])
		if e != nil || a > 999999 {
			return nil, nil, errors.New("version number out of range")
		}
		n[i] = a
	}
	var pre []string
	if m[4] != "" {
		pre = strings.Split(m[4], ".")
		for _, p := range pre {
			if p == "" {
				return nil, nil, errors.New("empty prerelease identifier")
			}
			if _, e := strconv.Atoi(p); e == nil && len(p) > 1 && p[0] == '0' {
				return nil, nil, errors.New("noncanonical prerelease")
			}
		}
	}
	return n, pre, nil
}
func compareVersion(a, b string) (int, error) {
	x, xp, e := versionParts(a)
	if e != nil {
		return 0, e
	}
	y, yp, e := versionParts(b)
	if e != nil {
		return 0, e
	}
	for i := range x {
		if x[i] < y[i] {
			return -1, nil
		}
		if x[i] > y[i] {
			return 1, nil
		}
	}
	if len(xp) == 0 && len(yp) > 0 {
		return 1, nil
	}
	if len(yp) == 0 && len(xp) > 0 {
		return -1, nil
	}
	for i := 0; i < len(xp) && i < len(yp); i++ {
		if xp[i] == yp[i] {
			continue
		}
		xn, xe := strconv.Atoi(xp[i])
		yn, ye := strconv.Atoi(yp[i])
		if xe == nil && ye == nil {
			if xn < yn {
				return -1, nil
			}
			return 1, nil
		}
		if xe == nil {
			return -1, nil
		}
		if ye == nil {
			return 1, nil
		}
		if xp[i] < yp[i] {
			return -1, nil
		}
		return 1, nil
	}
	if len(xp) < len(yp) {
		return -1, nil
	}
	if len(xp) > len(yp) {
		return 1, nil
	}
	return 0, nil
}
func allowedDownload(raw string) bool {
	u, e := url.Parse(raw)
	if e != nil || u.Scheme != "https" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Port() != "" {
		return false
	}
	if u.Host == "github.com" {
		p := strings.Split(u.Path, "/")
		return len(p) == 7 && strings.Join(p[1:3], "/") == repository && p[3] == "releases" && p[4] == "download" && tagPattern.MatchString(p[5]) && p[6] == archiveName
	}
	if u.Host == "raw.githubusercontent.com" {
		p := strings.Split(u.Path, "/")
		return len(p) == 5 && strings.Join(p[1:3], "/") == repository && regexp.MustCompile(`^[a-f0-9]{40}$`).MatchString(p[3]) && p[4] == archiveName
	}
	return false
}
func releaseManifest(r Release, preview bool) (Manifest, error) {
	var m Manifest
	if r.Draft || (r.Prerelease && !preview) || !tagPattern.MatchString(r.Tag) {
		return m, errors.New("release channel unavailable")
	}
	i := strings.Index(r.Body, manifestStart)
	if i < 0 {
		return m, errors.New("no updater manifest (legacy/source-only release)")
	}
	tail := r.Body[i+len(manifestStart):]
	end := strings.Index(tail, manifestEnd)
	if end < 0 || end > 8192 || strings.Contains(tail[end+len(manifestEnd):], manifestStart) {
		return m, errors.New("invalid manifest marker")
	}
	d := json.NewDecoder(strings.NewReader(tail[:end]))
	d.DisallowUnknownFields()
	if e := d.Decode(&m); e != nil {
		return m, e
	}
	var extra any
	if d.Decode(&extra) != io.EOF {
		return m, errors.New("trailing manifest data")
	}
	_, pre, e := versionParts(m.Version)
	if e != nil || (!r.Prerelease && len(pre) > 0) || m.Schema != 1 || m.Protocol != 1 || m.Tag != r.Tag || !allowedDownload(m.URL) || !digestPattern.MatchString(m.SHA256) || m.Bytes <= 0 || m.Bytes > maxArchive || m.Architecture != "x86_64" || m.BundleID != "local.aisora.companion" || m.MinMacOS != "13.0" {
		return m, errors.New("unsupported or unsafe update manifest")
	}
	if strings.HasPrefix(m.URL, "https://github.com/") && !strings.Contains(m.URL, "/download/"+m.Tag+"/") {
		return m, errors.New("archive belongs to a different tag")
	}
	return m, nil
}
func httpClient() *http.Client {
	return &http.Client{Timeout: 3 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) > 5 || req.URL.Scheme != "https" || req.URL.User != nil {
			return errors.New("unsafe redirect")
		}
		h := req.URL.Hostname()
		if h != "github.com" && h != "api.github.com" && h != "raw.githubusercontent.com" && h != "release-assets.githubusercontent.com" && h != "objects.githubusercontent.com" {
			return errors.New("unexpected download host")
		}
		return nil
	}}
}
func fetchJSON(ctx context.Context, path string, target any) error {
	req, e := http.NewRequestWithContext(ctx, "GET", apiRoot+path, nil)
	if e != nil {
		return e
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "AisoraUpdater/1")
	response, e := httpClient().Do(req)
	if e != nil {
		return e
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return fmt.Errorf("GitHub returned HTTP %d (release unavailable, offline or rate limited)", response.StatusCode)
	}
	b, e := io.ReadAll(io.LimitReader(response.Body, (4<<20)+1))
	if e != nil {
		return e
	}
	if len(b) > 4<<20 {
		return errors.New("release response too large")
	}
	return json.Unmarshal(b, target)
}
func selectLatest(releases []Release, installed string, preview bool) (Manifest, string, error) {
	var best Manifest
	var notes string
	for _, r := range releases {
		m, e := releaseManifest(r, preview)
		if e != nil {
			continue
		}
		c, e := compareVersion(m.Version, installed)
		if e != nil {
			return best, "", e
		}
		if c <= 0 {
			continue
		}
		if best.Version != "" {
			c, _ = compareVersion(m.Version, best.Version)
			if c <= 0 {
				continue
			}
		}
		best = m
		notes = strings.Split(r.Body, manifestStart)[0]
	}
	return best, notes, nil
}
func download(ctx context.Context, m Manifest, path string, progress func(int64)) error {
	return downloadUsing(ctx, httpClient(), m, path, progress)
}
func downloadUsing(ctx context.Context, client *http.Client, m Manifest, path string, progress func(int64)) error {
	part := path + ".part"
	defer os.Remove(part)
	request, e := http.NewRequestWithContext(ctx, "GET", m.URL, nil)
	if e != nil {
		return e
	}
	response, e := client.Do(request)
	if e != nil {
		return e
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return fmt.Errorf("download returned HTTP %d", response.StatusCode)
	}
	if response.ContentLength > 0 && response.ContentLength != m.Bytes {
		return errors.New("download length does not match approved manifest")
	}
	f, e := os.OpenFile(part, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if e != nil {
		return e
	}
	defer f.Close()
	h := sha256.New()
	reader := io.LimitReader(response.Body, m.Bytes+1)
	buffer := make([]byte, 128<<10)
	var total int64
	last := time.Now()
	for {
		n, err := reader.Read(buffer)
		if n > 0 {
			total += int64(n)
			if total > m.Bytes {
				return errors.New("archive exceeds declared size")
			}
			if _, e = f.Write(buffer[:n]); e != nil {
				return e
			}
			h.Write(buffer[:n])
			if time.Since(last) > time.Second {
				progress(total)
				last = time.Now()
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	if total != m.Bytes || hex.EncodeToString(h.Sum(nil)) != m.SHA256 {
		return errors.New("archive SHA-256/size mismatch; existing application was not changed")
	}
	if e = f.Sync(); e != nil {
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	return os.Rename(part, path)
}
