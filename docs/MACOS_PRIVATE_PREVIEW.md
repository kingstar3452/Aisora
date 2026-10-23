# Private Intel Mac preview — Ventura approval and local-build fallback

**Private testing only.** Version **6.1.0-rc.2** is ad-hoc signed, not notarized or generally trusted. The user's 23 October clarification authorizes a separate test using Apple's normal approval UI if offered. No paid Developer ID is required just to attempt that test. The currently installed working app is never replaced by these steps.

## Why the download was rejected

The current ZIP has Intel main/helper executables, correct permissions, complete Info/resource seals and valid ad-hoc signatures. Native macOS 15 CI starts the exported app headlessly and rejects deliberately corrupted resources. It also reports **Signature=adhoc, TeamIdentifier=not set**, no notarization, and **Gatekeeper rejection (exit 3)** for the quarantined copy. This is expected missing publisher/notarization trust; no additional bundle defect was found in those checks. Signature integrity, Gatekeeper policy and actual startup are separate results. The earlier unsealed release had a real packaging defect; that is already fixed in this candidate.

Ventura approval/Finder launch on the actual iMac remains **untested**. A normal local approval, if offered, is a user decision for this app; it does not make the archive notarized or establish updater-helper trust on every machine. See [Apple's supported opening/approval instructions](https://support.apple.com/en-sg/102445).

## Download and install separately

Use the versioned **v6.1.0-rc.2 private draft** in [repository Releases](https://github.com/kingstar3452/Aisora/releases), signed into the owner account. Exact current review/download links and checksum are in [the delivery receipt](private-preview-delivery.json). Draft URLs can change when edited; release ID **421423152** identifies this draft. Assets include `Aisora-phase6-macos.zip`, its SHA-256 file and native verification evidence. The authorized CI transfer resolved the earlier upload failure; the delivered ZIP was downloaded again and matched the original checksum/size.

```text
Aisora-phase6-macos.zip — 60,018,823 bytes
SHA-256 263dddb013d59a6207cd76a67f8d694f861e8e9ef224aba418e667598dd6710b
Native build commit 9095bceef8a0294c38850f1b874a7f508610a476
```

1. End Voice, then **Quit** the working Aisora. In Finder → Go → Go to Folder, open `~/Library/Application Support/Godot/app_userdata` and copy the **Aisora** folder somewhere safe. Both apps share this data; app rollback does not undo preference edits.
2. Extract the ZIP with Archive Utility. Create `~/Applications/Aisora Preview` in Finder and put the extracted **Aisora.app** there. Keep the app's name. Do not replace the working copy, run both copies, or launch through an old Dock/Spotlight shortcut.
3. Double-click that exact preview app once. If blocked, dismiss the warning without moving your working app to the Bin.
4. Open **System Settings → Privacy & Security**, scroll to **Security**, and look for Aisora's blocked-app notice. **If Open Anyway is offered**, choose it, authenticate normally if requested, and confirm **Open**. Apple says this option is available for about an hour after a blocked attempt. Review the app name/path; do not change broader security policy.
5. **If Open Anyway is absent, or macOS still refuses launch, stop.** In particular, do not override a new malware-specific warning. There is no quarantine removal, assessment exception, disabled Gatekeeper or Terminal launch workaround in this procedure. The next option is the source build below, or an authorized Developer ID/notarized distributor.

## Short acceptance and rollback

If it opens, confirm Settings → Aisora updates says **6.1.0-rc.2**. Check the character, mouth, original images and calibration; change one harmless preference, quit and reopen the preview to check persistence. With Voice ended, **Check for Updates** should start the bundled helper; this private draft is intentionally not an offered update. Then test one real Voice response and mouth movement. Record any helper/security failure instead of weakening checks. CI signature/atomic-swap tests do not establish the complete Ventura update transaction.

Enable **Check for updates on launch** and **Include preview releases** if desired; both choices are saved. Future accepted releases download/stage inside Aisora and require a separate **Restart to Update** after Voice ends. An approved Finder launch does **not** guarantee that the updater's separate `codesign`/Gatekeeper assessment accepts an ad-hoc replacement. Rejected updates remain blocked. Main preferences/images/calibration/pairing remain outside the app; no extension reinstall is needed.

To roll back this test, quit the preview and reopen the untouched working app. Keep the data backup. Restore that backup only with both apps closed if preference restoration is needed. Report the exact Ventura version, whether **Open Anyway** appeared, whether the preview opened, its installed-version label, and any helper/Voice error; do not send credentials or pairing files. Performance and authenticated Voice on this iMac remain unverified; [the report](PERFORMANCE_RC2.md) retains the speaking P99 regression.

## Alternative: genuine local source build

This creates a standalone app **from verified source on your Mac**, not a rewrapped downloaded binary. It does not strip quarantine or claim downloaded-app trust. You need **Python 3.12+**, **official Godot 4.6.3 standard**, **official Go 1.27.3 darwin/amd64**, and **Apple Command Line Tools** for native signing/architecture tools. Install each through its normal official installer/approval. A free Apple account may be needed for Apple's standalone Command Line Tools download; paid Developer ID membership is not required for ad-hoc building. If Apple's installer cannot connect, resolve that normal installation first; the builder queries the tools and stops, without invoking their installer or altering the system selection.

[Focused Intel Mac CI 39943982520](https://github.com/kingstar3452/Aisora/actions/runs/39943982520) passes at the exact source commit below: verified source-ZIP export without git, native Intel signatures, actual headless app/helper startup, and a normal windowed **LaunchServices** launch. It runs on **macOS 15.7.9**, with Apple build tools installed, and does not test human Finder/Open Anyway or Ventura. Its formal `spctl` assessment still rejects the ad-hoc app; no override was added. [Native evidence](local-build-native-validation.json). Thirteen focused source-build safety checks also pass. CI's `git archive` ZIP and the user's GitHub source ZIP have different archive hashes but the same verified source commit/files.

Official tools: [Python](https://www.python.org/downloads/macos/), [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable), [Go](https://go.dev/dl/), [Apple developer tools](https://developer.apple.com/download/all/?q=command%20line%20tools). Build tools are needed once, not to run the finished app. Allow roughly **4 GB free disk** and a stable connection: the existing helper verifies the official **1.26 GB export-template archive** before retaining its needed files. Build caches/templates stay inside this extracted source tree.

Download this [pinned source ZIP](https://github.com/kingstar3452/Aisora/archive/6d139bc308112fa1ab3b56c0a5c00b472559b658.zip), keep it as `Aisora-6d139bc308112fa1ab3b56c0a5c00b472559b658.zip` in Downloads, and extract it there. All **424 files** were compared with that exact Git commit before writing these instructions. Source ZIP SHA-256 (different from the application ZIP above):

```text
28561c1e0700cfdf4a1bdecfad62150292d2e2dfc83e852f1a6e779b7363268a
```

In Terminal, run the source build (these are build commands, not security workarounds):

```sh
cd "$HOME/Downloads/Aisora-6d139bc308112fa1ab3b56c0a5c00b472559b658"
python3 tools/build_local_macos.py \
  --archive "$HOME/Downloads/Aisora-6d139bc308112fa1ab3b56c0a5c00b472559b658.zip" \
  --archive-sha256 28561c1e0700cfdf4a1bdecfad62150292d2e2dfc83e852f1a6e779b7363268a \
  --source-commit 6d139bc308112fa1ab3b56c0a5c00b472559b658
```

Put Godot in `/Applications/Godot.app` or `~/Applications/Godot.app`; otherwise set `GODOT_BIN` to its executable before the build. Set `AISORA_GO` if the official Go executable is not on PATH. The builder verifies the source ZIP and extracted files, refuses altered/extra source or an existing output folder, exports and ad-hoc signs the helper/app using the existing workflow, verifies integrity/Intel architecture, and records the policy assessment **without overriding it**. No Git checkout is needed and the archive build does not invoke git.

The result is under `exports/local-preview-6d139bc30811/Aisora.app`, with a local ZIP and `local-build-receipt.json`. It has its **own checksum**, not the prebuilt ZIP checksum. Nothing is automatically installed or launched. Back up shared data, then use Finder to move this locally built app to a separate `~/Applications/Aisora Local Preview` folder and test normally. Local origin does not guarantee acceptance; if macOS still refuses, stop and report the receipt/normal warning. A verified source build is a private alternative, not a generally trusted redistribution fix.
