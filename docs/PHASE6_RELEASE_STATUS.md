# Phase 6 preview release decision — 23 October 2026, Asia/Singapore

**Result: stop before public publication.** The user has conditionally authorized preview publication after artifact integrity and a supported macOS installation path are verified. Artifact integrity passes, but **Gatekeeper rejects the quarantined ad-hoc build**. No Developer ID/notarization credentials have been provided. A preview label or checksum cannot satisfy this missing trust requirement. Stable-release acceptance has not been granted or established.

## Exact candidate

| Item | Value |
| --- | --- |
| Build version | **6.1.0-rc.2**, preview/test candidate |
| Versioned private draft | [v6.1.0-rc.2](https://github.com/kingstar3452/Aisora/releases/tag/untagged-338c20c7d3a0458a3c76), release ID **421423152**; not published |
| Native build commit | **9095bceef8a0294c38850f1b874a7f508610a476** |
| Production runtime commit | **2142475b0cc9f8386e64929db1486746e9115e8b**; later development changes are CI/tests/tools/docs |
| Target | Intel **x86_64**, macOS **13.0+**, official Godot **4.6.3** Compatibility workflow/templates |
| Archive | `Aisora-phase6-macos.zip`, **60,018,823 bytes** |
| SHA-256 | `263dddb013d59a6207cd76a67f8d694f861e8e9ef224aba418e667598dd6710b` |
| Signing/trust | Ad-hoc; no Developer ID, no notarization; native Gatekeeper assessment **rejected, exit 3** |

The versioned draft's new asset upload failed with **HTTP 401: Bad credentials** at `uploads.github.com`; no files were attached to that draft. The exact tested binary is still accessible through the original, untouched [native-validation private draft](https://github.com/kingstar3452/Aisora/releases/tag/untagged-1db13c3057e44d8033ad), release ID **421151792**, ZIP asset ID **666951269**: [direct ZIP](https://github.com/kingstar3452/Aisora/releases/download/untagged-1db13c3057e44d8033ad/Aisora-phase6-macos.zip). Owner login is required. If draft links change after editing, find the draft in [repository Releases](https://github.com/kingstar3452/Aisora/releases). There is no public versioned release or public artifact fallback.

The draft deliberately has **no update-discovery manifest**: a known Gatekeeper-rejected candidate must not be offered as an installable update. Approved future builds need fresh final bytes/checksums and matching release metadata after signing/notarization. Existing public releases, the previous drafts and the user's installed app are preserved.

## Verification retained, without unnecessary repeats

Previously passed evidence is reused: **1,324 core Linux checks plus 13 Go test groups/vet**, and **14 native Intel Mac Go groups/vet** including actual XNU atomic directory exchange/reversal. Native Apple strict/deep signature checks, `ditto` extraction, Intel main/helper architecture, execute permissions, headless exported-app startup, packed actual-VRM autonomy/body/face checks and deliberate resource-corruption rejection pass. Signature consistency is distinct from Gatekeeper trust.

The release-preparation check re-read the actual ZIP's SHA-256/size, embedded version/source and main/helper execute bits and matched them to the retained verification record. No source rebuild or full suite rerun was necessary because production runtime/resources are unchanged.

Measurements retain **615 Linux rendering cases**, **72 native Mac state cases**, and **18 explicit-source headless probe records**. Mac CI is **macOS 15.7.9 / Apple Software Renderer**; it is not the target Ventura/iMac, a physical GPU benchmark or normal Finder launch. Authenticated ChatGPT Voice/audio capture, Ventura launch, true editor UI comparison, sustained target-device performance and the complete LaunchServices health/rollback transaction remain unverified. See [test evidence](TEST_RESULTS.md) and [all raw data and checksums](benchmarks/rc2/REVIEW.md).

## P99 concern and preview limitation

The repeated complete Linux-player comparison records simulated-speaking P99 **51.64 → 80.83 ms** from rc.1 to rc.2, with rc.2 speaking P95 spanning **39.22–232.30 ms** across repetitions. Idle P95 improves **47.07 → 40.53 ms**, but that does not cancel the speaking tail regression. Historical-workload and some preset/weather/resolution tests also regress. All valid slow runs remain included.

Rendering dominates the component profile; accepted sub-millisecond script changes cannot explain the complete render tails. Shared-host variation/software-renderer saturation limit attribution, but have not been proven to be the cause of every regression. The P99 regression is **documented, not fixed or dismissed**. No universal improvement or stable 30 FPS on the 2017 iMac is claimed. The [full performance report](PERFORMANCE_RC2.md) provides all scenarios, mean/median/P95/P99/FPS/CPU/RSS and repeated ranges. Target-device profiling remains necessary.

## Auto-update function and saved settings

These functions are already implemented in the candidate; no duplicate updater was added:

- **Settings → Aisora updates → Check for updates on launch** enables automatic checks. **Include preview releases** selects eligible published previews. Both preferences survive restart and default to opt-in.
- **Download & Install Update** handles downloading, checksum/bundle/Apple validation and staging inside Aisora. **Restart to Update** acts after Voice ends and Aisora closes, with an atomic swap and retained rollback copy. There is no unattended installation during Voice and no installation of a rejected/unverified archive.
- The currently installed older app cannot acquire the updater remotely. **One initial, safely accepted updater-enabled installation is required**; afterwards future accepted releases can be handled inside the app rather than repeatedly downloading/extracting/reinstalling through the browser. A writable home Applications location avoids an administrator requirement.
- App settings persist in `user://settings.cfg`; updater selections persist in `user://updates/preferences.cfg`. `user://` resolves to `~/Library/Application Support/Godot/app_userdata/Aisora` for this project, outside `Aisora.app`. Local images, calibration and pairing references use the existing data architecture and are not replaced by the updater.
- Existing tests exercise restart/reload of updater preferences, background assignments, behavior/personality/autonomy preferences, unknown-key preservation, pairing/calibration retention and the one-time migration backup. Complete update/persistence acceptance on the user's Mac is still required. App rollback does not undo later preference edits.

See [UPDATES.md](UPDATES.md) for exact controls, staging safeguards, recovery and failure cases. The bridge/extension remains separate and unchanged.

## Legitimate signing and distribution prerequisite

An authorized signing maintainer needs a valid **Developer ID Application** identity/private key and Apple notarization access configured through secure keychain/CI secret storage. An existing organization or trusted authorized distributor can supply the signing service; the user does not necessarily need to own a separate paid account. No such signing capability has been supplied here. Do not paste certificates/private keys/passwords into chat.

The supported completion path is to finalize the app contents, natively sign the helper and app in the appropriate order with hardened runtime, a secure timestamp and reviewed Godot-compatible entitlements, verify Apple's signatures/identity, submit for notarization and require **Accepted**, staple/validate the ticket, then package without losing signed/stapled metadata. Verify the final archive's structure/architecture/permissions/checksum and a native Gatekeeper assessment, then test an Internet-downloaded, quarantine-preserving copy through ordinary Ventura/Finder controls. Signing alone is not notarization or a launch test.

The current exporter/CI and Python independent signature verifier explicitly handle **ad-hoc candidates**; they must not be advertised as an automated Developer ID/notarization pipeline or relaxed to make a certificate-signed build appear verified. A native trusted-signing finishing/verification path must be used and validated when authorized signing access is available. The app and updater need no paid developer account to run, but this does not confer trusted Internet distribution on an ad-hoc binary. Repeatedly ad-hoc signing/re-zipping the same app will not solve the acceptance failure.

GitHub asset-upload authentication must also be repaired before attaching the final trusted archive. Repository reads/draft preparation work, but the upload endpoint rejected both the batch and a small checksum-only attempt. This is an HTTP authentication failure, not an automatic approval-review rejection. No public branch/asset workaround was used while the installation condition is unmet.

## Safe installation and rollback

**For the current rejected candidate: keep the working installation; no supported normal-install path is verified.** Do not disable Gatekeeper, strip quarantine, add assessment exceptions, change security policy or use Terminal launch workarounds.

After a trusted preview passes the release gate:

1. Keep the working app and quit it. In Finder → Go → Go to Folder, back up `~/Library/Application Support/Godot/app_userdata/Aisora`.
2. Extract the approved ZIP with Archive Utility and put `Aisora.app` in a separate `~/Applications/Aisora Preview` folder. Keep the app name; do not run from a ZIP preview.
3. Open through ordinary Finder/macOS controls. If it reports damaged or denies launch without normal approval, stop; do not weaken security.
4. Test settings/image/calibration/pairing persistence, animations, actual Voice/lip sync and the [same-condition performance checklist](PERFORMANCE_RC2.md#local-acceptance-gate). Enable launch checks/preview releases if desired; those choices are saved.
5. To roll back the separate preview test, quit it and reopen the untouched working app. Retain the data backup in case preference restoration is needed. For a later accepted in-app update, use **Restore Previous Version** only after closing Voice; see the health/rollback limitations in [UPDATES.md](UPDATES.md).

**Next prerequisite:** authorized trusted signing/notarization and repaired asset-upload access, followed by native installation verification. Conditional preview approval is already recorded; no stable-release claim is authorized. Until the prerequisite is available, stop before public publication rather than rebuild or repeat passed tests.
