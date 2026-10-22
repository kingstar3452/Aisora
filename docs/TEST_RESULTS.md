# Implementation and validation record

## Autonomy preferences candidate — 22 October 2026 (publication held)

The preferred-default integration passes **1,318 core automated checks**, plus the retained **12 Go updater test groups and go vet**. The additional 42 Godot checks exercise Talkative/mouse/hover/environment/quiet-hours defaults, saved overrides, interruption history, quiet ranges, daily caps/cooldowns, Voice/uncertain-session suppression, actual-rig eye transforms and local environment metadata. Unknown Voice status in a connected selected browser suppresses unsolicited events. The live Python bridge suite passes 15 checks with browser/audio fixtures; no bridge protocol or extension changes were needed.

All **42 autonomy checks** also pass using the actual project pack from the final Mac ZIP, including its bundled copyable personality document. That pack passes **24 articulated-body/framing checks and 6 facial checks** using Godot Compatibility on Linux llvmpipe. Actual open/closed mouth images differ by 29/33/26 pixels at Low/Balanced/High in the full-body 960×600 scene. These counts show localized visible morph changes, not a quantitative measure of facial quality.

The four character shader sources remain byte-identical to rc.1. A frozen-reference image comparison passed all 33 checks in an independent repeat; the first pass is retained with one seated-frame pixel difference (25/255 in one channel, one of 576,000 pixels), despite identical shader source. This is a reproducibility limitation, not a discarded performance outlier. No shader quality reduction is claimed. A separate cursor scheduling experiment passed its own 42 policy tests but was reverted after repeated input benchmarks worsened aggregate frame times. Its raw runs remain archived; it is not included in this candidate.

A fresh official-template Godot 4.6.3 Intel Mac ZIP was built from **90a9cdedcba89982350a2e1a9147b6a415764a77**, SHA-256 **38e269f41dee2c95f317fe73e353945f6c024fd4f900d144f0aeb0d23352040f**, with independently verified main/helper x86_64 architecture, executable permissions, ZIP CRC, code pages, Info/resource seals and nested helper signature. It is ad-hoc only, unpublished and not a certified native launch. Linux pack/player testing cannot establish macOS Gatekeeper, Archive Utility, authenticated Voice or 2017 Intel iMac performance. See [autonomy controls and manual Project configuration](AUTONOMY.md). The ongoing performance report remains a release gate; these commits do not authorize publication or replace the installed app.

## Updater/facial clarity candidate — 22 October 2026

The updater-enabled 6.1.0-rc.1 candidate passes **555 core checks**: 32 Python, 28 JavaScript, 35 original model, 58 Phase 2, 38 Phase 3, 117 Phase 4, 93 Phase 5, 103 Phase 6, 15 HTTP/bridge fixtures and 36 new update/face/preference checks. The dependency-free Go updater adds **12 test groups** with corruption, traversal, permissions, interrupted download/journal, duplicate task, version/channel, Voice and idempotent restoration cases, plus `go vet`. Transaction exchanges in these Linux tests are injected fixtures, not the native macOS syscall.

Real Godot Compatibility rendering passes **24 retained Phase 6 checks plus 6 new facial checks**. Fixed-pose open/closed mouth renders from the actual VRM differ visibly on Low/Balanced/High (30/32/30 pixels at the deliberately full-body 960×600 frame). The Linux app export contains Intel main/helper executables and independently verified nested code/resource seals. Native macOS signing/Gatekeeper, quarantine, atomic exchange, LaunchServices/health and authenticated Voice remain local acceptance items. See [updater safety and setup](UPDATES.md) and [measured frame-time/CPU/RSS comparison](PERFORMANCE_UPDATER.md); there is no claim of consistent 30 FPS on the iMac.

## macOS signing repair

The reported damaged download matches the published checksum. The old app has correct Intel executable permissions and matching machine-code page hashes but lacks an Aisora CodeResources seal/Info.plist binding. Basic ZIP/resource checks missed that packaging defect. The repair adds complete-app ad-hoc signing after all content changes, an independent code-page/special-slot/resource hash verifier, atomic output replacement, and 11 packaging regression tests. Full runtime functionality is unchanged. The repaired candidate passes 516 core checks and 24 real Compatibility rendering checks against its extracted pack in Linux, plus code-page/special-slot/resource hash validation. Native codesign, Gatekeeper and macOS launch tests remain unperformed. See [repair findings, test scope and remaining Apple trust requirements](MACOS_LAUNCH_REPAIR.md). Linux consistency checks are not native Gatekeeper or launch tests.


## Phase 6 implementation validation (before the packaging repair)

Godot **4.6.3 official / Compatibility**, Linux cloud, **21 October 2026**. The core runner passes **505 checks/tests**: 18 Python, 28 JavaScript, 35 original actual-model/state, 58 Phase 2, 38 Phase 3, 117 Phase 4, 93 Phase 5, **103 Phase 6** and 15 live local Godot/HTTP fixture checks. Script imports and JavaScript syntax pass. The original VRM SHA-256 remains `46f3ec42b2dca1558b936f37dc0927af906e294f278cf756c0c329a1d23dab68`; Phase 5 supplied backgrounds are unchanged.

The new actual-rig suite exercises four articulated walking directions, stepped 90° turns, planted-foot error below 15 mm, lifted swing feet, bounded continuous root motion and return; supported seat heights, sit/recline/sleep/reverse contacts; sampled CPU-skinned body/hair/face floor and boundary envelopes; restoration of original clothing attachments; sleeping shifts and Voice get-up; all ten personality gestures at maximum intensity, coarse limb/body proxies, morph cleanup and silent speech-mouth ownership; local preference persistence, byte-preserving one-time settings backup, zero/single weighted choices and cooldowns. Floor samples use an 8 mm tolerance, not full continuous triangle collision detection.

A **one-hour simulated session on the actual VRM** advances 54,000 ticks at 15 Hz, with recurring simulated conversations and morning/night context. Seeded output is **122 major selections, 66 movement, 23 personality and 16 rest starts**, including all four walking directions and floor sleep. No new action begins during a call; the character finishes at the original anchor. This is accelerated simulation, not an hour of target-device rendering or authenticated Voice.

Separate Xvfb/Mesa real OpenGL suites pass **70 checks**: 24 new Phase 6, 26 retained Phase 5, 15 retained Phase 4 and 5 retained Phase 3. They cover full-body framing and exact standing-camera restoration, native versus transparent reduced-resolution rendering, simulated Voice speaking/listening during get-up, all three presets seated, calibration/clean mode, narrow-window settings and deferred rain image changes, plus retained time/weather/image/aspect/mouth/shadow/fallback behavior. The expanded preview label initially pushed the settings panel beyond the window; shortening it fixes the retained regression test. The Phase 6 check now verifies both scrollbar page and panel edge.

The real-Chromium simulated-page test passes two start/end cycles, unchanged conversation, no dictation, visible Thinking/permission markers, ambiguous-control refusal and navigation disconnect. Worker/bridge tests additionally cover Project-label validation, conversation-only selection, concurrent binding, browser-session reselection, pending-call guards, confirmed-state ownership, stale-command cancellation, binding-tagged late-audio rejection and listening-marker priority. Live HTTP tests retain stale sample handling, duplicate-start refusal and repair after 401 while render polling is capped. Browser transport/page/audio are fixtures: **native authenticated ChatGPT Voice is not certified**.

Multi-angle captures sample all ten authored personality actions and eight transition times for sitting, reclining and sleeping, plus returned poses. Four-direction walking and retained ground actions have three-angle entrance/swing/return sheets. These are actual imported rig renders, not generated concept art. The visible lying posture is a simple supine bent-knee rest; no side-lying, polished mocap, arbitrary chair matching or full cloth collision is claimed. See [Phase 6 controls and limitations](PHASE6.md).

An actual unsigned **Intel x86_64 macOS app ZIP** and Linux release executable/PCK export successfully. The export helper checks ZIP integrity, app identity, resource-pack presence and the x86_64 Mach-O executable, then adds the exact engine notices and SHA-256 sidecar. An isolated editor-based pack player decodes all five supplied images and instantiates the original rig/main scene from both the Linux PCK and the resource pack extracted from the final Mac app ZIP. The Linux release executable boots/renders using its own pack. Short clean-settings standalone versus editor-player FPS observations are recorded with the severe initial standalone stall retained; they do not prove sustained pacing. The Mac executable is **not run on Linux**, and is not signed or notarized.

Uncapped before/after results in [PERFORMANCE_PHASE6.md](PERFORMANCE_PHASE6.md) include all runs and show **slower Phase 6 wall frames** on this software renderer despite unchanged draws/primitives/video accounting and small added script time. Stage microbenchmarks and exported-player observations are separate from iMac performance. No sustained 30 FPS or thermal claim is made. Native Mac window focus/minimize/file dialogs, unsigned app launch/Gatekeeper, real microphone/output capture, browser Voice DOM compatibility and long-running Intel GPU performance remain local acceptance items.

```sh
./tools/check.sh
# Display required; Xvfb/software OpenGL verifies functionality, not Intel Mac speed:
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase6.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase5.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase4.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase3.gd
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_phase6.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_ground.gd
./tools/run_godot.sh --headless --script res://tools/audit_sheets.gd
./tools/run_godot.sh --headless --script res://tools/profile_phase6.gd
```


## Phase 5: historical validation

Godot **4.6.3 official, Compatibility**, Linux cloud, 18 October 2026. The final core runner passes **389 checks/tests**: 13 Python, 20 JavaScript, 35 original model/state, 58 retained Phase 2, 38 retained Phase 3, 117 retained Phase 4, **93 Phase 5** and 15 live Godot/HTTP integration checks. A clean staged-source archive independently imports from scratch and passes the full runner. The VRM SHA-256 remains `46f3ec42b2dca1558b936f37dc0927af906e294f278cf756c0c329a1d23dab68`. Bridge/extension source is unchanged in this phase.

The Phase 5 suite tests exact local-time boundaries/manual overrides, ordered custom schedules, real supplied-image decoding/size budgets, old-sunset preservation, unique persistent local imports, missing-image/light retention, eased two-texture fades, worker replacement on assignment changes, rain priority/clear restoration, layer caps/off/pause, clean UI, text-input shortcut isolation, optional ambience load/duck, actual-rig cached FK, all 15 gestures at maximum intensity, queued gesture blends, calibrated steps/returns/contacts/bounds, Voice hold/resume, per-image calibration/control restoration, nighttime Voice priority, optional adaptive resolution and restart migration.

Separate real software OpenGL checks pass **26 Phase 5 + 15 retained Phase 4 + 5 retained Phase 3** checks. These verify all five actual pictures and character light, actual alpha crossfades, preserved aspect, a shared-world transparent reduced-resolution character render without duplication, native UI/background, original model silhouette and placement, Low/Balanced/High transparency, rain motion/pause, mist, clean/settings layout, minimized 3D suppression and the optional 3D fallback. See [sunset](images/phase5-sunset.png) and [night](images/phase5-night.png) composition previews.

All 15 actual-VRM standing poses were inspected [front](images/phase5-actions-front.png) and from [both](images/phase5-actions-side.png) [sides](images/phase5-actions-other-side.png); sampled peaks had zero approximate proxy hits/held candidates. All five short movement sequences were sampled at six times from three angles on a developer-only flat ground; they returned home, with maximum measured planted-foot error about **3.2 mm** in that visual run. The automated contact tolerance is 15 mm. [Pacing samples](images/phase5-ground-pace.png). These samples do not certify arbitrary combined poses, cloth collision or unrestricted walking. Seat/floor transitions remain unimplemented.

A macOS-target PCK exports successfully. From an empty project directory, an isolated Godot player decodes all five images from that pack and instantiates its main scene, original skeleton and background. This verifies resource packaging, **not a macOS binary**, signing or target-device operation. The supplied backgrounds are raw Keep File resources with an explicit export inclusion filter.

The simulated Chromium test passes two Voice start/end cycles, unchanged conversation, no dictation, explicit Thinking/permission markers, ambiguity refusal and navigation disconnect. Real loopback HTTP integration retains fresh mouth/state handling at a 5 FPS cap, repair after 401 and duplicate-start protection; browser/audio sources remain simulated. No native authenticated ChatGPT Voice success is claimed.

[PERFORMANCE_PHASE5.md](PERFORMANCE_PHASE5.md) contains uncapped comparisons with Phase 4 and raw records: native median means improve only about 2% within overlapping ranges, primitives drop 40%, script cost increases, and reduced resolution has mixed results including a severe outlier. No general speedup or sustained 30 FPS claim is made. [PHASE5.md](PHASE5.md) documents installation, settings, calibration and local acceptance. Native Voice, physical capture/playback/permissions, audible ambience, macOS file dialogs/focus/hotkeys, a Mac binary export and sustained target-iMac performance/thermals remain untested.

```sh
./tools/check.sh
# Display required; Xvfb/Mesa suffices for functional rendering:
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase5.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase4.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase3.gd
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
# Resource packaging (Mac/Linux; godot must be on PATH):
./tools/run_godot.sh --headless --editor --export-pack macOS /tmp/aisora-test.pck
mkdir -p /tmp/aisora-pack-only
godot --headless --path /tmp/aisora-pack-only --main-pack /tmp/aisora-test.pck --script "$PWD/tests/check_export_pack.gd"
# Actual-rig visual audits; output stays in ignored .local/:
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_phase5.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_ground.gd
```

## Phase 4: historical validation

Godot **4.6.3 official, Compatibility**, Linux cloud, 18 October 2026 UTC. The core runner passes **296 checks/tests**: 13 Python, 20 JavaScript, 35 actual-model/state, 58 retained Phase 2, 38 retained Phase 3, **117 Phase 4** and **15 real Godot/HTTP integration** checks. Import and script-error checks pass. A clean staged-source archive independently imports from scratch and passes the entire 296-check core runner. The original VRM SHA-256 remains `46f3ec42b2dca1558b936f37dc0927af906e294f278cf756c0c329a1d23dab68`.

A separate real OpenGL suite passes **15 hybrid rendering checks**: aspect-preserving image circles, native canvas composition, original character visibility/proportions, amplitude mouth pixels, ground shadow, stationary effects at Off, animated/paused petals, Balanced/High transparency, fallback, resized positioning and settings without horizontal scrolling. The existing **5 Phase 3 render checks** also pass with the optional park selected. The standing-action gallery samples all 15 actions on the actual VRM at entrance, peak and exit; left/right gaze additionally samples both directions. It does not certify walk, turn, sit, floor rest or rising from a floor. Those remain unavailable, with standing sleep/wake retained.

The Phase 4 suite exercises bounded PNG/JPEG/WebP loading, pre-decode dimension checks, private copies, invalid-image retention, transparent foreground rejection, texture budgets, layer pause/off/caps, lazy fallback geometry, anchor/scale persistence, actual finger joints, authored hand positions, eased poses, unavailable-action refusal, weighted/zero/single action scheduling, conversation fade/preview guards, explicit Thinking versus output amplitude, pairing rejection and settings migration. Browser tests cover authenticated pairing before replacement, capture serialization/readoption, session guards, fixed permission diagnostics, busy command deferral and fresh activity metadata.

The live local HTTP fixture verifies fresh mouth/state updates with a **5 FPS** minimized render cap, explicit Start/End, repair after a real 401 during a simulated active call, conservative animation guarding while disconnected, and repeated Start preserving an ongoing call. Chromium's simulated page completes two start/end cycles without navigation or dictation, checks visible activity/permission markers, and refuses ambiguous controls. Browser/audio sources are fixtures; these results **do not establish native ChatGPT Voice support**.

Controlled uncapped comparisons show median per-run mean **49.15 → 25.57 ms** talking and **43.84 → 21.55 ms** idle, with **29 → 24 draw calls** and **58,022 → 39,794 submitted primitives**. Talking p95 still exceeds 33.3 ms. Full Phase 3 comparisons and raw run records are in [PERFORMANCE_PHASE4.md](PERFORMANCE_PHASE4.md). They use the bundled original illustration, not the user-selected picture: the attached image files were not exposed in the cloud filesystem. The preferred first picture is supported through the local picker. Native authenticated Voice, real capture/playback/permissions, Mac file dialogs/window events/hotkeys, an exported build and sustained 2017 Intel iMac pacing/thermals remain untested. Follow [PHASE4.md](PHASE4.md) for local acceptance.

```sh
./tools/check.sh
# Requires a display; Xvfb/software OpenGL suffices for functional checks:
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase4.gd
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase3.gd
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
```

## Phase 3: historical validation

Godot **4.6.3 official, Compatibility**, Linux cloud, 17 October 2026 UTC / 18 October Singapore. The final core check runs **164 checks/tests** with zero failures: 10 Python, 13 JavaScript, 35 actual-model/state, 58 retained animation/park/settings, 38 new optimization/preset/diagnostic and 10 real Godot/HTTP integration checks. Godot import and script log checks also pass. A clean staged-source archive independently imports from scratch and passes the 35 model and 38 Phase 3 checks. The original VRM SHA-256 remains `46f3ec42b2dca1558b936f37dc0927af906e294f278cf756c0c329a1d23dab68`.

The new tests verify exact rest-axis quaternion equivalence on every actual bone, unchanged native-write skipping, cached amplitude mouth deformation/exact silence, independent imported expressions, lower-frequency hair while primary motion continues, all three presets' original texture retention, exact High material restoration, material reuse, lighting control/alpha preservation, low-power override/restoration, legacy preference migration/restart and F3's bounded sampling/checkbox behavior.

A separate real OpenGL test passes **5 checks**: rendered petals move, paused petals remain stationary, and the character renders visibly in Low/Balanced/High. Software OpenGL previews for all eight existing samples (Idle, Wave, Stretch, Listening, Talking, Sleeping, Waking, Settings) render successfully. Simulated Chromium DOM testing passes two start/end cycles, unchanged conversation, no dictation, ambiguity refusal and navigation disconnect. These are fixtures, not a native ChatGPT session.

Controlled uncapped comparisons show median per-run mean wall time **82.34 → 47.47 ms** while talking and **79.99 → 43.89 ms** while idle, with 47 → 29 draw calls in Low. See [PERFORMANCE.md](PERFORMANCE.md) for complete methodology, noisy ranges, p95, memory, preset costs and raw per-run records. This does **not** demonstrate steady 30 FPS in software or on the target iMac. CPU-script tail timing did not consistently improve; native rendering cost and shared-host stalls remain.

The browser extension, bridge protocol/client, importer and original VRM are unchanged in Phase 3. The actual HTTP integration still verifies fresh status and amplitude mouth animation at a 5 FPS cap using a simulated browser/audio source. No cloud test certifies native consumer Voice, physical audio permissions/playback, macOS events/hotkeys, target iMac pacing/thermals or an exported Mac build. Follow [Phase 3 local testing](PHASE3.md) and [SETUP_MAC.md](SETUP_MAC.md).

```sh
./tools/check.sh
# Requires a display (Xvfb/software OpenGL is sufficient for functional rendering):
./tools/run_godot.sh --audio-driver Dummy --script res://tests/render_phase3.gd
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
```

## Phase 2: historical record


Phase 2 extends `dev/aisora-companion` using Godot **4.6.3 official**, Compatibility rendering, Python 3.12.14, Node 24.19 and local Chromium 154. Validation is in Linux cloud (18 October 2026, Singapore date), with an actual VRM and simulated consumer-browser/audio sources. It does not certify native Voice or performance on macOS.

| Check | Result and meaning |
| --- | --- |
| Actual model / original states | **35 checks passed**. Face/Body/Hair textures, imported skeleton and facial bindings, all five states, simultaneous blink/mouth, silence/stale audio closure and sleep FPS behavior. Sleep checks now allow the deliberate 2.4-second settling transition. |
| Phase 2 animation / park / settings | **57 checks passed**. Simultaneous layers on the actual skeleton, visible head/hair motion, wave hand above elbow, all gestures with finite rotations, slow sleeping breath, rest/wake transitions, focused listening gaze, amplitude-only mouth, intensity controls, deterministic randomized schedules, eight trees/three blossom batches/two branch batches, batched bench/path/grass, falling/off/capped/suspended petals, rendering policies, resizable-window defaults, and new/legacy/unknown preference persistence. |
| Python local bridge | **10 tests passed**. Real loopback HTTP authentication, web-origin/rebinding rejection, command IDs, one-time delivery, timeout, error persistence, audio expiry/clamping and private pairing configuration. |
| JavaScript extension/policy | **13 tests passed**. Voice-only matching and command policy, selected tab/conversation routing, capture constraints, scalar RMS calculation, playback reconnection and cleanup, refusal of ambiguous/disabled/dictation controls. Browser APIs are explicitly mocked. |
| Godot ↔ real HTTP bridge | **10 checks passed** with simulated browser/output. Actual Godot HTTP command/status processing drives the real mouth shape and TALKING state. An active session and fresh status continue while render cap is **5 FPS**, end commands/silence still work while minimized, and foreground restoration returns to 30 FPS. |
| Simulated ChatGPT DOM in Chromium | Two complete start/end cycles, unchanged conversation URL, no dictation activation, ambiguity refusal and disconnect on navigation. The fixture now waits for actual state/command acknowledgments instead of racing fixed 1.1-second sleeps against the one-second heartbeat. Only DOM and extension transport are simulated; no actual ChatGPT account is used. |
| Rendered poses / park | Software OpenGL previews inspected for Idle, Wave, Stretch, Listening, Talking, Sleeping, Waking and Settings. Actual original character remains in the foreground; hand/shoulder gestures, rest pose, path/grass/trees/bench, opaque petals and performance menu render. |

The new minimized test first exposed render-dependent HTTP progress/timeouts in the original client. Using Godot's supported `HTTPRequest.use_threads` for both requests fixes it; the same test now passes at 5 FPS. Failed/empty responses also avoid noisy JSON parsing errors. This tests the local controller, not the remote consumer Voice service.

## Reproduce

```sh
./tools/check.sh
# Optional: Python Playwright + a local Chromium executable, never a real ChatGPT/profile:
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
# Optional rendered pose set, requires a display:
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_preview.gd -- --sheet
```

`check.sh` preserves runner exit codes and verifies nonzero completed Godot suites and parse/runtime logs. The Phase 2 settings test uses an isolated temporary preference file and removes it, rather than modifying the user's preferences. Screenshots stay in ignored `.local/`.

Batching tree branches and bench parts reduced the inspected Settings scene from 170 to 115 draw calls; the primitive monitor remained 104,461. These are software-renderer/debug-scene counts, not a target-machine FPS result.

Software rendering uses Xvfb/Mesa llvmpipe and Dummy audio. The virtual display warns that changing VSync is unsupported. It is useful for render inspection, not an Intel iMac frame-rate or thermal benchmark. No physical output audio was captured.

## Not verified on this machine

- Native ChatGPT Voice in an authenticated browser, real tabCapture permissions, audible playback, output-vs-microphone separation. Cloud browser administrator policy blocks unpacked extensions; it was not changed or bypassed.
- macOS Ventura focus/minimize event delivery and wake/resume behavior with a real call, Samsung display/full-screen behavior, optional Carbon global F8 and sustained 2017 iMac CPU/GPU load. The automated background test supplies focus/minimize flags explicitly while using actual HTTP.
- Full cloth/hair collision physics, foot IK or bench seating. Sleep is a standing resting pose; hair uses bounded root rotations. The original VRM remains byte-for-byte unchanged.

Use [the Mac checklist](SETUP_MAC.md) and [performance controls](PHASE2.md) for those acceptance checks. No additional installation is required for Phase 2 beyond updating the existing branch and letting Godot import the scripts.
