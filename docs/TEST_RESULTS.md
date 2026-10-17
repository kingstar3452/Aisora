# Implementation and validation record

Validated in the Linux cloud on 18 October 2026 (Singapore date), with **Godot 4.6.3 official**, Python 3.12.14, Node 24.19 and local Chromium 154. This is not a macOS or live consumer-Voice certification.

| Milestone | Evidence | Remaining local verification |
| --- | --- | --- |
| 1 · VRM | Actual uploaded VRM 0.0 imported and instantiated. Face, Body and Hair meshes have textures; humanoid skeleton and mouth/blink expression bindings are present. Software OpenGL scene render inspected. Model bytes unchanged after moving its path. | Check appearance and materials on Intel macOS Compatibility renderer. |
| 2 · Presentation / animation | Godot asset/state suite: **35 checks, zero failures**. Covers real mesh textures/bindings, each state, simultaneous blink + mouth, head motion, closed sleeping eyes/mouth, RMS attack/release/silence/staleness and sleep FPS cap. Render inspected for centered character, relaxed arms and full-body framing/stage. | Judge motion quality, macOS display/full-screen behavior, keyboard focus and comfort locally. |
| 3 · Native Voice controller | **10 Python bridge tests** and **13 Node extension/policy tests** pass. Simulated ChatGPT DOM in real Chromium completes **two start/end cycles**, retains URL, ignores dictation, refuses ambiguity, disconnects after conversation navigation. Commands confirm a resulting visible control rather than treating a click as success. | Installed-extension and real native ChatGPT start/end unverified. Cloud administrator policy blocks unpacked extensions; real account/microphone permissions are not available here. No policy was changed to bypass that restriction. |
| 4 · Output audio / lip sync | RMS analyzer test uses tab-only capture constraints, verifies scalar-only output, playback connection and track cleanup. Godot tests verify smoothing, silence and stale-data closure using the actual mouth shape. | Real tabCapture/offscreen permission, AudioContext start, speaker playback and output/microphone separation need Mac testing. No raw audio capture was performed in cloud. |
| 5 · Integration / performance | Godot's real local HTTP client → Python bridge → simulated browser/output completes **5 checks**, including command-driven TALKING, actual facial movement, ending/silence and return to idle. Low-power Compatibility defaults, static gradient, no shadows/post effects, disabled spring modifier, state-specific FPS caps. | 30 FPS is a target, not a measured 2017 iMac result. Optional Carbon global hotkey cannot compile or run on this Linux host. |

## Reproduce

```sh
./tools/check.sh
# Optional: requires Python Playwright and local Chromium, no real ChatGPT/profile:
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
# Optional: requires a display; outputs ignored .local/preview.png:
./tools/run_godot.sh --audio-driver Dummy --script res://tools/capture_preview.gd
```

`check.sh` preserves command exit codes and checks Godot logs for parse/runtime errors as well. Godot import may emit editor progress messages; zero executed tests are not accepted as readiness. Browser API tests use mocks explicitly; browser DOM tests simulate only extension messaging and the ChatGPT UI. The live-local-bridge test uses actual HTTP/Godot with a simulated browser and scalar audio source. None contacts ChatGPT.

A software OpenGL render used an isolated Xvfb display and Mesa llvmpipe. The virtual driver warned that changing VSync is unsupported; the render completed without shader/runtime errors using Godot's Dummy audio driver, since no physical cloud audio output exists. Screenshots stay in ignored `.local/` and are not published as character assets.

The repository includes no conventional game motion clips; all listed motion is procedural. Hair physics is deliberately disabled for the default low-power workflow. Unsupported native controls, browser restrictions and missing permissions remain explicit errors/manual fallbacks instead of fabricated success.
