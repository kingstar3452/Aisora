# Implementation and validation record

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
