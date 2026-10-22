# Updater-enabled Phase 6 — 6.1.0-rc.1

This is a review candidate. Publication requires user approval. Development and Linux tests do not modify the currently installed Mac app.

## One-time installation

The old app has no updater, so one initial installation is necessary. After approval/publication, leave the working app in place, download the new Intel ZIP, extract it with Finder/Archive Utility, and first place **Aisora.app** in a separate **~/Applications/Aisora Preview** folder (create it in Finder if necessary). Quit the working app before testing the preview. Keep the app's name. After local acceptance, keep that writable location or move it once to your preferred home Applications location. A writable home installation avoids administrator privileges. Do not run from an image/ZIP preview/App Translocation directory.

Open with normal macOS controls. **If macOS says damaged without offering approval, stop.** This candidate is ad-hoc signed, not Developer ID signed/notarized; native Ventura launch remains untested. Do not remove quarantine or disable Gatekeeper. Godot, Go, Python and a developer account are not required to run the app/updater; the existing separate Voice bridge keeps its original requirements.

Settings → **Aisora updates** shows installed/latest version, notes and status. Launch checks default off; preview releases require their own opt-in. Checks defer during Voice. There is no GitHub account/token entry or telemetry.

For the extension error in chat, Chrome's **Load unpacked** must select **browser-controller/extension**, which contains `manifest.json`, **not the repository's top-level folder**. The updater does not reinstall a working extension or alter its browser session.

## Future updates

**Check for Updates** reads versioned public GitHub Releases in `kingstar3452/Aisora`. Drafts, legacy/source-only releases without compatible metadata, older/equal versions and nonselected preview releases are skipped.

**Download & Install Update** downloads and stages first. It never replaces the running app. **Restart to Update** requires separate confirmation after Voice ends. Staging stops if Voice begins. Known active/pending Voice, audio, or a latched conversation guard blocks restart. The helper rechecks the authenticated local bridge before and after waiting for Aisora to close. If browser state is unobservable, explicit confirmation that Voice ended is required; undetectable browser activity cannot be inferred reliably.

The bundled external helper validates a sibling app, waits for Aisora and other instances to exit, revalidates, then uses macOS's atomic `renameatx_np(RENAME_SWAP)` directory exchange. There is no delete-first/two-rename fallback. The old app remains at its recorded sibling path as a rollback copy. The new app must survive 30 seconds with its character/UI loaded and acknowledge the matching transaction token/version. Early startup failure restores the old app when no new instance is running. A health timeout with a possibly live app retains both copies and reports unconfirmed status; it never kills or replaces that live app. Close Aisora and use **Restore Previous Version** for recovery.

Existing settings, local image alternatives, avatar/floor calibration, bridge pairing references and user files stay in the existing user-data directory outside the app. The updater writes only its `updates` subdirectory and uniquely named sibling bundles. It never touches browser profiles, cookies or credentials. App rollback does not undo later preference edits; future incompatible data migrations need their own backup strategy before release.

## Validation and security boundaries

The updater is a compiled Intel executable sealed inside Aisora.app. It never executes downloaded scripts, invokes a shell, escalates privileges or grants security exceptions.

- Release metadata is bounded inert JSON in the GitHub release body: semantic version, tag, exact size/SHA-256, bundle identity, Intel architecture, macOS requirement and updater protocol. HTTPS/repository control provide provenance; a checksum is **not an independent publisher signature**. A compromised repository account remains a threat.
- Downloads allow only this repository's HTTPS release assets or **immutable 40-character artifact commits**, with known GitHub HTTPS redirect hosts. Mutable branches/external script URLs are refused.
- Time/size limits, `.part` files, SHA-256, ZIP CRC, canonical/unique paths, symlinks, file types, expanded-size limits, executable permissions, identity/version, Intel main/helper executables and required resources are checked before staging. The staged tree is hashed and checked again before installation.
- The downloader **adds/preserves Internet quarantine**. Native `codesign --verify --deep --strict` and `spctl --assess --type execute` must both accept the staged app, and run again before replacement. Metadata cannot substitute for these checks.
- **Quarantined ad-hoc builds will commonly be rejected by Gatekeeper. Installation then stays blocked.** Use ordinary macOS approval only if actually offered, then retry validation. There is no quarantine removal or assessment bypass. Building an updater needs no paid account; reliable unattended acceptance of public Internet-downloaded ad-hoc apps cannot be promised. Normally trusted distribution still needs Developer ID signing/notarization.

## Failures and recovery

| Failure | Result |
| --- | --- |
| Offline/rate limited/missing release | Retryable status; no app change. |
| Interrupted, corrupt or wrong-size download | No finished download accepted; retry; original untouched. |
| Unsafe ZIP, wrong architecture/version, Apple rejection | Installation blocked before replacement. |
| Permissions/disk space | Staging fails; use a writable home Applications folder; no sudo prompt. |
| Voice begins | Staging/restart cancels while app remains installed. |
| App remains running for 90 seconds | Helper stops without swapping it. |
| Filesystem refuses atomic exchange | Safe failure; no non-atomic fallback. |
| Interrupted journal/exchange | An app remains at the original path; version inspection determines rollback direction. Repeated rollback cannot reinstall the failed build. |
| Early new-app exit | Restore previous app if no Aisora instance remains running. |
| Health unconfirmed but app may be running | Keep backup; close app before manual restoration. |

**Show downloaded update / update files** reveals staging/status records. The latest transaction records the rollback path. Keep it until local acceptance. Interrupted tasks can leave unused download/hidden sibling folders; they are never auto-executed. After identifying them from the transaction record and verifying a working installation, old update caches/copies can be removed manually. Do not delete the main user-data directory. Cleanup is intentionally conservative in this first updater.

## Development and approval workflow

```sh
./tools/check.sh
python3 tools/prepare_export_templates.py
python3 tools/prepare_macos_signer.py
python3 tools/export_macos.py --output exports/Aisora-phase6-macos.zip
python3 tools/macos_bundle.py exports/Aisora-phase6-macos.zip
python3 tools/prepare_update_release.py \
  --archive exports/Aisora-phase6-macos.zip --tag v6.1.0-rc.1 \
  --notes /path/to/reviewed-notes.md --output-dir .local/update-release
```

Official Godot **4.6.3** Intel templates are retained. The Go helper has no third-party module dependencies or additional runtime installation. Linux bootstraps a checksum-pinned official Go development toolchain; Mac builders can set `AISORA_GO` to Go 1.25+. Every Info.plist/helper/notice change precedes final signing. Independent checks include the nested helper's CodeDirectory/resource seal. Linux ad-hoc consistency is not Apple acceptance.

Create a **draft** versioned release with the reviewed notes, tested ZIP, checksum and verification record. Obtain approval **before publishing**; use the preview channel until native acceptance. Never advertise a raw Godot export or source ZIP as an update. The release body is discovery metadata, not executable instructions.

If GitHub asset uploads fail, after approval store the finished ZIP at an immutable artifact commit in this repository and regenerate notes with `--download-url https://raw.githubusercontent.com/kingstar3452/Aisora/COMMIT/Aisora-phase6-macos.zip`. Never use a branch URL. Versioned Releases remain the update source.

Future changes require a version bump, tests/export, review, approval and publication. Updater-enabled apps then offer the newer version without reinstalling manually **when macOS accepts that replacement**. Bridge/extension updates remain separately reviewed; this change preserves both unchanged.

## Local Mac acceptance still needed

Linux tests cover validation, transaction failure injection, simulated Voice, actual-VRM regression/rendering and before/after measurements. They cannot certify Intel Ventura helper/syscall execution, native Apple assessments, Archive Utility quarantine, LaunchServices/health acknowledgement, APFS/HFS+ replacement, authenticated ChatGPT Voice or iMac performance.

On a spare home-folder installation test channels/notes, interrupted/corrupt downloads, permissions/disk full, blocked ad-hoc updates, Voice beginning during download/restart, duplicate instances, an accepted update, early exit/health timeout, interruption recovery and repeated rollback. Confirm all settings/images/calibration/pairing survive. Keep the working installation until these pass. See [performance evidence](PERFORMANCE_UPDATER.md).
