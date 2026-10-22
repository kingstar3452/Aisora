# Aisora

The updater-enabled **6.1.0-rc.1 preview** adds reviewed GitHub Release discovery, staged native installation/rollback and conversation-first facial clarity. See [one-time installation, future updates and Gatekeeper limits](docs/UPDATES.md). The [approved preview](https://github.com/kingstar3452/Aisora/releases/tag/v6.1.0-rc.1) is published; native Mac acceptance is still pending. Existing Mac installations are untouched.

A lightweight Godot 4 anime companion over an illustrated sakura background or in the optional 3D park for an Intel Mac. Godot presents your existing VRM character; native ChatGPT Voice in your normal browser handles the conversation. No paid API, TTS engine, second language model, or memory service is included.

**Tested engine: Godot 4.6.3, Compatibility renderer.** The uploaded project advertised `4.7 / Forward Plus`; it had no scenes, scripts, or engine binary pin. This implementation explicitly selects the tested stable version and OpenGL Compatibility for the 2017 iMac.

Phase 6 continues on `dev/aisora-companion`: bounded four-direction skeletal walking, step turns, calibrated sitting/reclining/sleep/get-up, opt-in local autonomy and ten reusable personality gestures. Existing Phase 5 images, clock, weather and settings are preserved. The selected-Project-conversation Voice bridge adds safer binding/reconnection; native Voice still needs local Mac verification. See [Phase 6 setup and limits](docs/PHASE6.md), [performance evidence](docs/PERFORMANCE_PHASE6.md) and [test results](docs/TEST_RESULTS.md).

For the standalone macOS launch failure, use the [bundle-signing repair candidate and limitations](docs/MACOS_LAUNCH_REPAIR.md). Its verified ad-hoc seals do not establish Apple Developer ID trust, notarization or native Ventura launch success.

## Start on your Mac

1. Install the standard **Godot 4.6.3 editor** from [godotengine.org](https://godotengine.org/download/archive/4.6.3-stable/) and open this repository's `project.godot`. Allow the first VRM import to finish. Both bundled plugins should be enabled under Project Settings → Plugins.
2. Press **Run Project** (F6 runs a scene; use the editor's Run Project button or F5). Aisora should appear. Everything in the character viewer works without a browser or bridge.
3. Open **Chrome or Edge 116+** on your existing Aisora ChatGPT Project conversation and sign in normally. The extension supports Chromium browsers; Safari is a manual-Voice fallback.
4. For experimental browser control and lip sync, follow [the short browser setup](docs/SETUP_MAC.md). You need Python 3.10+ to run the small local bridge; it uses only the standard library.

Do not enter ChatGPT passwords, cookies, or session tokens into this project. The extension uses the page's normal signed-in interface and requests normal capture permissions. ChatGPT account/Voice usage limits still apply.

## Controls

| Control | Effect |
| --- | --- |
| F8 (F9 option in Settings) | Toggle native Voice while the Godot window is focused |
| 0 | Automatic presentation state |
| 1 / 2 / 3 / 4 / 5 | Test Idle / Listening / Thinking / Talking / Sleeping |
| Tab / Settings button | Graphics, local scenery picker, placement, action scheduler, Voice recovery, FPS and audio |
| F3 | Toggle FPS, mean/p95 frame time and draw-call diagnostics |
| F11 | Full-screen / windowed; move the window to the Samsung display first |
| Escape | Leave full-screen |
| H | Hide/show the interface for a clean dedicated display |
| Browser Command+Shift+8 | Toggle selected Voice tab, configurable in extension shortcuts |

F8 is **not** a system-wide shortcut unless you run the optional [macOS hotkey helper](docs/SETUP_MAC.md#optional-global-f8). macOS may require Fn+F8. Test mode 4 needs output capture to move the mouth; Settings → Test mouth supplies clearly labeled synthetic amplitude for offline testing.

## What is implemented

- Your VRM 0.0 model, imported with its original embedded textures, humanoid skeleton, and available facial controls. Low/Balanced use efficient textured shading; High restores the original MToon materials/outlines. No replacement character. A native canvas background keeps her fully 3D; optional reduced-resolution rendering shares the same world and model.
- Optional procedural Japanese cherry blossom park: eight sakura trees, pink blossom clusters, grass, a winding path, a wooden bench, a garden lantern, warm daylight and sparse falling petals. Original baked blossom/grass textures, merged curved wood/props and instanced cutout foliage; no asset downloads. Aisora stays centered and unobstructed.
- A local PNG/JPEG/WebP background picker with covered aspect scaling, uniform 3D character scale/placement, separate ground shadow, optional transparent foreground, instanced petals and gentle lighting/parallax. The five supplied Phase 5 pictures are bundled as optimized WebP; custom picker imports stay in local application data. Local-clock time slots, rain priority and matching 3D lighting preserve the previous imported sunset as an alternative.
- Layered breathing, gaze, posture, gestures and facial animation, with randomized timing. Visible swaying/weight shifts, waves, stretches, looking around, posture adjustments, speech-linked head/hand gestures, focused listening, and small hair-root motion. The retained manual sleep state uses a standing rest; the separate Phase 6 controller provides calibrated floor sleep and get-up. The painted bench remains scenery.
- Five-state presentation controller with manual test overrides. Automatic mode distinguishes listening/talking from detected Voice state and output audio. Thinking follows an explicit visible Voice indicator when detected; otherwise use the manual test state. Silence alone never implies Thinking.
- Authenticated loopback bridge and unpacked Chromium extension: explicit existing-tab selection, start/end/toggle attempts, visible-control state detection, command confirmation/timeouts, disconnect recovery, manual fallback.
- Optional **ChatGPT tab output** capture in an offscreen extension document. Only scalar RMS amplitude leaves the audio analyzer; no microphone capture, recordings, or audio uploads. Smoothed mouth opening, silence gate and stale-audio closure. This is amplitude lip sync, not phoneme timing.
- Standard resizable window by default. Foreground target 30 FPS, optional low-power 15 FPS, inactive 10 FPS, minimized 5 FPS, settled sleep 10 FPS. Background throttling keeps the Voice bridge running. Settings persist Low/Balanced/High quality, character placement, scenery/character intensity, petal density, FPS, diagnostics, scheduler intervals and action weights. Secondary motion runs at reduced frequency; unchanged bone/face values skip native writes. Hair uses bounded procedural root motion; full spring simulation remains disabled.

Phase 6 adds bounded four-direction walks and configurable 15–90° stepped turns that return home, virtual-seat/floor rest, ten authored personality gestures and opt-in weighted time-aware autonomy. Conversation takes priority. These are conservative rig-specific procedural poses, with supported seat heights and clothing limits; see [Phase 6 calibration and acceptance](docs/PHASE6.md).

## Validation and limitations

See [milestone evidence](docs/TEST_RESULTS.md) for exact results and [troubleshooting](docs/TROUBLESHOOTING.md) for recovery steps. Deterministic tests and simulated browser controls **do not prove live native Voice works on your Mac**. Real ChatGPT controls, capture permissions/audio playback, global hotkeys, macOS window behavior, and iMac performance require local acceptance checks.

The bridge/extension do not select or create a ChatGPT Project or conversation: you select the existing tab explicitly. They never navigate it. If ChatGPT itself changes routing, stop and select your intended conversation again.

## Repository

| Folder | Purpose |
| --- | --- |
| `assets/character/` | Original uploaded VRM and importer settings |
| `addons/` | Pinned Godot VRM / MToon importer and license notices |
| `scenes/` | Main scene |
| `scripts/` | Layered character motion, procedural park, rendering policy, envelope, bridge client and settings |
| `animations/` | Procedural animation design and extension points |
| `browser-controller/` | Local Python bridge and Chromium extension |
| `tools/` | Launch, validation, optional macOS global hotkey, render check |
| `tests/` | Existing-asset integration, bridge, browser policy and simulated browser tests |
| `docs/` | Mac setup, research, evidence, troubleshooting |

## Development checks

Godot 4.6.3, Python 3.10+, Node 18+ and a POSIX shell are sufficient for core checks:

```sh
./tools/check.sh
```

Set `GODOT_BIN` if Godot is not installed in `/Applications/Godot.app` or on PATH. Node is a **test tool only**, not an application dependency. The optional browser smoke test uses Python Playwright and a local Chromium test browser; see its file header. Generated caches, pairing keys, local helper binaries, and logs are ignored by Git.

This cloud task already has an isolated checkout; use it directly rather than creating a worktree. No export templates are needed to run in the editor. To export a Mac application later, install matching Godot export templates and review macOS signing/microphone behavior for your own distribution. Keep the bridge external; point an exported viewer at its pairing file with `AISORA_BRIDGE_CONFIG=/absolute/path/to/bridge.json`.

See [third-party notices](docs/THIRD_PARTY.md). The character's embedded VRM license metadata remains intact and separate from the importer license.
