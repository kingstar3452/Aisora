# Aisora 6.1.0-rc.2 — private ad-hoc review candidate

**Publication held; performance and normal macOS launch acceptance remain open.** This candidate preserves the Phase 6 body/personality animations, full-detail face, amplitude mouth sync, local image/weather/time system, bridge/extension and user-data paths. It adds the staged external updater and requested configurable autonomy defaults, plus conservative rest-pose reuse and median/P99 diagnostics. Saved choices override defaults. Proactive comments are local text/events only; Project personality instructions require manual copy, and proactive ChatGPT Voice is unsupported.

The [full performance report](PERFORMANCE_RC2.md) includes all measured gains and regressions against the working repair and rc.1. Complete Linux-player idle P95 improves **47.07 → 40.53 ms**; speaking P99 worsens **51.64 → 80.83 ms**. Historical-workload and several quality/resolution/weather cases also regress. Three repetitions are retained for every scenario; no universal speedup or stable iMac 30 FPS is established.

Validation: **1,324 core Linux checks plus 13 Go groups/vet**, actual-VRM pack/render checks, **615 Linux rendering cases**, **72 native Intel Mac project-player cases**, and **18 explicit-source headless probes**. Native macOS 15.7.9 CI additionally passes 14 Go groups/vet, real atomic exchange/reversal, strict Apple codesign, headless exported-app startup, packed character checks and deliberate corruption rejection. Its Apple Software Renderer is not the target iMac GPU. Actual authenticated Voice, Ventura/Finder launch, target-device performance and the complete native update-health/rollback transaction remain untested.

## Build and download

- [Owner-private draft](https://github.com/kingstar3452/Aisora/releases/tag/untagged-46f17c529d7d1e3c8e7f) — sign into the repository owner account.
- [Direct ZIP](https://github.com/kingstar3452/Aisora/releases/download/untagged-46f17c529d7d1e3c8e7f/Aisora-phase6-macos.zip), **60,018,823 bytes**, Intel **x86_64**, official Godot **4.6.3** templates, minimum macOS **13.0** because of the helper.
- SHA-256: `263dddb013d59a6207cd76a67f8d694f861e8e9ef224aba418e667598dd6710b`.
- Build source **9095bceef8a0294c38850f1b874a7f508610a476**, production runtime **2142475b0cc9f8386e64929db1486746e9115e8b**. Later changes are CI/tests/tools/docs, not untested runtime additions.

The ZIP is complete and ad-hoc signed, **not Developer ID signed or notarized**. **Gatekeeper rejects the quarantined copy in native CI (exit 3).** Downloading this draft does not solve the damaged-app/normal-launch problem. It is preserved for review, not recommended as a replacement or advertised as a verified updater installation. The nonversioned draft is intentionally invisible to update discovery.

## Separate preview test, only if macOS permits normal launch

1. Keep the working installed app. Download the ZIP from the owner-private draft and extract with Archive Utility.
2. In Finder create `~/Applications/Aisora Preview` and place the extracted `Aisora.app` there. Do not rename the app or run it from a ZIP preview.
3. Quit the working app. In Finder → Go → Go to Folder, open `~/Library/Application Support/Godot/app_userdata` and back up the **Aisora** folder; the preview uses the same settings/images/calibration/pairing data.
4. Open the preview through normal macOS controls. **If the damaged-app error appears without ordinary approval, stop.** No Terminal quarantine changes or security disabling are part of these instructions.
5. If normal launch succeeds, follow [the local performance checklist](PERFORMANCE_RC2.md#local-acceptance-gate), [autonomy checks](AUTONOMY.md#validation-and-local-acceptance), and [updater failure/rollback acceptance](UPDATES.md#local-mac-acceptance-still-needed). Close the preview before reopening the working app. Preserve the data backup; app rollback does not undo preference edits.

No Godot or Go installation is needed to run the app/updater. The separate Voice bridge keeps its existing Python/browser installation requirements. Future updater releases need a bumped version, tests, measurements, a complete archive/checksum, fresh approval and publication. Installation still requires macOS to accept the replacement; paid credentials are not required for the updater code, but reliable unattended trust for Internet-distributed ad-hoc apps cannot be promised.
