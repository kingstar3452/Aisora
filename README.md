# Aisora

A lightweight Godot 4 anime companion for an Intel Mac. Godot presents your existing VRM character; native ChatGPT Voice in your normal browser handles the conversation. No paid API, TTS engine, second language model, or memory service is included.

**Tested engine: Godot 4.6.3, Compatibility renderer.** The uploaded project advertised `4.7 / Forward Plus`; it had no scenes, scripts, or engine binary pin. This implementation explicitly selects the tested stable version and OpenGL Compatibility for the 2017 iMac.

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
| Tab / Settings button | Camera, light, quality, FPS, audio sensitivity, shortcut, mouth test |
| F11 | Full-screen / windowed; move the window to the Samsung display first |
| Escape | Leave full-screen |
| H | Hide/show the interface for a clean dedicated display |
| Browser Command+Shift+8 | Toggle selected Voice tab, configurable in extension shortcuts |

F8 is **not** a system-wide shortcut unless you run the optional [macOS hotkey helper](docs/SETUP_MAC.md#optional-global-f8). macOS may require Fn+F8. Test mode 4 needs output capture to move the mouth; Settings → Test mouth supplies clearly labeled synthetic amplitude for offline testing.

## What is implemented

- Your VRM 0.0 model, imported with its original embedded textures, MToon materials, humanoid skeleton, and available facial controls. No replacement character.
- Framed 3D scene, matte stage, soft color palette, two simple lights, configurable camera and lighting.
- Procedural resting arms, breathing, irregular blinks, gaze shifts, head/upper-body motion, listening tilt, thinking pose, subtle speaking gestures, closed-eye sleeping, smooth expression transitions.
- Five-state presentation controller with manual test overrides. Automatic mode distinguishes listening/talking from detected Voice state and output audio. **Thinking cannot be inferred reliably from silence and remains a manual test state.**
- Authenticated loopback bridge and unpacked Chromium extension: explicit existing-tab selection, start/end/toggle attempts, visible-control state detection, command confirmation/timeouts, disconnect recovery, manual fallback.
- Optional **ChatGPT tab output** capture in an offscreen extension document. Only scalar RMS amplitude leaves the audio analyzer; no microphone capture, recordings, or audio uploads. Smoothed mouth opening, silence gate and stale-audio closure. This is amplitude lip sync, not phoneme timing.
- Default active cap 30 FPS, idle 20, sleeping 10. Low-power rendering by default; optional 2× MSAA. Hair spring simulation is disabled at runtime for predictable cost. Authored hair and materials are retained.

## Validation and limitations

See [milestone evidence](docs/TEST_RESULTS.md) for exact results and [troubleshooting](docs/TROUBLESHOOTING.md) for recovery steps. Deterministic tests and simulated browser controls **do not prove live native Voice works on your Mac**. Real ChatGPT controls, capture permissions/audio playback, global hotkeys, macOS window behavior, and iMac performance require local acceptance checks.

The bridge/extension do not select or create a ChatGPT Project or conversation: you select the existing tab explicitly. They never navigate it. If ChatGPT itself changes routing, stop and select your intended conversation again.

## Repository

| Folder | Purpose |
| --- | --- |
| `assets/character/` | Original uploaded VRM and importer settings |
| `addons/` | Pinned Godot VRM / MToon importer and license notices |
| `scenes/` | Main scene |
| `scripts/` | Character state machine, envelope, bridge client, presentation/settings |
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
