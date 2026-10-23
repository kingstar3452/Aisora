# Exact continuation checkpoint — 23 October 2026, Asia/Singapore

## Recovered phase and first unfinished task

The latest workstream is **Proactive Dialogue, Mouse Awareness & Personality Persistence**, continuing on the existing **Phase 6 application/updater**, version **6.1.0-rc.2**. Its original attachment has a separate ten-phase plan: **Phase 7 is the Autonomy interface**, already implemented; interruption occurred during **Phases 8–9 (animation/performance validation and testing), leading into Phase 10 delivery**. Those workstream phases must not be renamed Phase 6 merely because the app/release documentation uses that base version. Repository `kingstar3452/Aisora`, development branch `dev/aisora-companion`, existing [PR #1](https://github.com/kingstar3452/Aisora/pull/1). Do not restart implementation, reset local work, rewrite history or publish.

At interruption, runtime **2142475b0cc9f8386e64929db1486746e9115e8b** was frozen and tested; native validation source **9095bceef8a0294c38850f1b874a7f508610a476** adds only CI/tests. The last development commit **f4d8a6a** enforced explicit headless-profile provenance and withdrew stale figures from an old launcher that had reused the wrong source path. Original shaders/meshes were restored after rejected experiments. The unfinished task was to collect the remaining repeated benchmarks, audit the results, complete the before/after report and prepare review material. Those jobs have now finished; none needs restarting.

## Implemented and preserved

- External updater code: Settings checks/optional launch checks, installed/latest version/notes/status, bounded release metadata, checksum/archive/bundle validation, quarantine and native Apple verification, staging while the app remains intact, Voice guards, atomic after-exit exchange, backup/journal, startup acknowledgement and rollback controls. Native end-to-end accepted Internet update/LaunchServices health/rollback remains unverified.
- Full VRM/body/personality animations, mouth amplitude envelope, face detail/lighting, imported image slots/weather/local clock, calibration, existing settings/data paths, bridge and extension remain. Accepted performance changes reuse rest-pose FK/orthonormal inverses and retain bounded median/P99 diagnostics; no animation or face quality was removed.
- Preferred configurable defaults: Talkative, in-window mouse tracking, hover reactions, environment comments and quiet hours on. Persisted user choices win. Rate limits, daily counters, DND/silence/quiet-time and Voice/unknown-session suppression are implemented. Actual-rig head/eye direction was corrected and tested.
- Versioned copyable Project personality instructions and local curated text/event fallback. This does **not** provide supported proactive ChatGPT Voice, automatic Project-context injection, emotion detection from Voice, global mouse sensing or screen observation.

## Completed checks and evidence

- Final Linux core: **1,324 checks**, plus **13 Go test groups/vet**; zero failures. Packed-resource checks: 48 autonomy, 24 articulated-body/framing and six facial checks. Strict shader-reference repeat: 33 passes; the earlier single-pixel seated discrepancy remains documented.
- **615 Linux rendering cases**, **72 native Intel Mac state cases**, **18 explicit-source headless probe records** complete. All valid slow runs retained. Main/input/Mac count, repetition, trace length, CPU and summary medians audited; native summary regenerates identically. Source/runtime/harness fingerprints are recorded.
- [Native validation 39843983384](https://github.com/kingstar3452/Aisora/actions/runs/39843983384): macOS 15.7.9 Intel, official Godot 4.6.3, 14 Go groups/vet, real XNU directory exchange/reversal, ditto/permissions/x86_64, strict Apple codesign, headless exported-app startup, packed rig/face/autonomy checks and deliberate resource corruption rejection.
- [Native performance 39846700428](https://github.com/kingstar3452/Aisora/actions/runs/39846700428): original eight Low states × three revisions × three repetitions. Apple **Software Renderer**; not a physical GPU or Ventura/iMac benchmark. Fixed-source adapter/workflow retained in development history.
- Native ZIP downloaded and independently reverified on Linux after CI. All lossless raw data, tables, logs/receipts and directory SHA-256 manifest: [benchmarks/rc2/REVIEW.md](benchmarks/rc2/REVIEW.md).

## Failures, limitations and open acceptance

The autonomy workstream's architecture audit, local mouse/event controller, manual Project-personality configuration, environment metadata and Phase 7 settings are implemented. The supported fallback for its Phase 4 proactive-dialogue requirement is local text/events, not unsupported Voice prompting. Phase 8's no-performance-regression acceptance is **not met across all measurements**; Phase 9 automated coverage is complete but target-device acceptance is not. Phase 10 review material is prepared and publication remains blocked. This distinction between implemented code and unmet acceptance is intentional.

**Publication HOLD remains.** The [completed performance report](PERFORMANCE_RC2.md) shows favorable Linux idle/rest results but unresolved regressions in speaking tails, historical workload, some quality/weather/resolution cases and native software-renderer comparisons. No all-scenario speedup, stable target 30 FPS, reduced overall CPU/memory, physical GPU measurement or absence-of-leaks claim is justified. Rejected trials were reverted; the remaining cross-environment differences are not conclusively attributed to host noise.

**Gatekeeper rejects the quarantined ad-hoc candidate, exit 3, with assessments enabled.** Developer ID/notarization credentials are unavailable. No quarantine removal, security bypass or normally trusted launch claim is permitted. Automated checks cannot overcome that distribution constraint.

Target 2017 Intel iMac/Ventura, Retina drawable resolution, sustained thermals, actual authenticated browser Voice/audio capture, Finder launch, true editor-UI comparison, and complete LaunchServices health/rollback/user-data acceptance need local testing through a supported launch path. The current environment cannot complete them. Do not overwrite the user's installed working app. A separate preview shares user data; back up that folder in Finder before any local acceptance test.

## Candidate and rollback

Owner-private draft ID **421151792**, nonversioned tag `aisora-native-validation-39843983384` (updater ignores it): [review page](https://github.com/kingstar3452/Aisora/releases/tag/untagged-1db13c3057e44d8033ad). Native `Aisora-phase6-macos.zip`, **60,018,823 bytes**, SHA-256 **263dddb013d59a6207cd76a67f8d694f861e8e9ef224aba418e667598dd6710b**. This is an ad-hoc review/test candidate, not an approved/trusted replacement. Previous working release and rc.1 draft remain preserved. Runtime can be inspected at 2142475; no rollback of the installed Mac was needed because it was never changed.

Recovered uncommitted work consisted of the preview data-backup clarification plus the generated review/raw/summary files. It was preserved and incorporated, not discarded. New recovery changes are documentation, evidence, the native performance CI/tool merge, and a portable summary catalogue option/OS-neutral memory label. Production runtime/resources remain identical to the native test ZIP's source.

## Next unfinished action

Review [the report](PERFORMANCE_RC2.md) and [candidate notes](RELEASE_RC2_REVIEW.md). Keep publication held. Further performance work needs same-condition target-device profiling and a supported launch path; if macOS offers no ordinary approval, stop. Do not ask for credentials already declined or silently bypass protections. Fresh publication approval must follow evidence review and must not be inferred from the earlier generic approval. Any runtime change requires new matched comparisons and relevant validation; do not rerun completed suites merely to select favorable scores.
