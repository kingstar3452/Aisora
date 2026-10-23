# Mac setup

For the standalone private preview, start with [separate installation, Ventura Open Anyway, and the verified local-build fallback](MACOS_PRIVATE_PREVIEW.md). Keep the working installation. The local builder exports from a pinned source ZIP without git and needs normal Apple build tools; it does not remove quarantine or change security policy.

For standalone updates, see [one-time updater installation and Gatekeeper limits](UPDATES.md). If Chrome reports **Manifest file is missing**, select the nested **browser-controller/extension** folder in Load unpacked, not the downloaded repository root.

Start with [Phase 6](PHASE6.md) for current full-body/personality controls, calibration, optional autonomy, export and rollback. Phase 5 backgrounds, local sunset alternatives and pairing files are preserved. Reload extension **0.3.1**, refresh your intended Project conversation, then explicitly select it again and restart output capture if needed. Keep your normal authenticated browser session; signing out is unnecessary.


For repeated pairing failures or several extracted source folders, follow the [0.3.1 pairing repair guide](BRIDGE_PAIRING_REPAIR.md) first. It includes a visible permanent configuration path, Reconnect/Reset, and a secret-free authentication diagnostic. No standalone app rebuild is needed.

## 1. Run the character

Use Godot **4.6.3 standard**, Compatibility renderer, on macOS Ventura. Open `project.godot` and wait for the import progress to finish. Click Run Project. The default is a normal resizable window, Low graphics and 30 FPS. Enable Low-power mode for a 15 FPS foreground cap. Move the window onto the Samsung monitor before using F11/full-screen. macOS Spaces and “Displays have separate Spaces” settings affect which display owns a full-screen window.

The first import can take longer than later launches. Aisora should appear over the supplied picture selected by the Mac's local clock (or your chosen local picture), with breathing, irregular blinks and visible idle movement. Test states with 1–5; return to automatic with 0. Tab opens Performance & presentation: Low/Balanced/High quality, Low-power mode (15 FPS), animation intensity, petal density, foreground FPS and an F3 frame-time overlay. Under Standing actions, choose one of the 15 supported actions and click Preview selected action after ending Voice. Settings remain in Godot's local `user://settings.cfg`; existing camera/audio/shortcut preferences are preserved. See [Phase 5](PHASE5.md) for image slots, weather, calibration, render-resolution controls, local testing and standing rest/wake behavior.

## 2. Start the local bridge

Install [Python 3.10 or newer](https://www.python.org/downloads/macos/) if `python3 --version` is unavailable. No `pip install` is needed. In Finder, double-click `tools/start_bridge.command`; leave that Terminal open. Alternatively:

```sh
cd /path/to/Aisora
python3 browser-controller/bridge.py
```

It binds only to `127.0.0.1:8765` and creates `.local/bridge.json` with a random, local-only pairing key. **This is not a ChatGPT credential.** It is excluded from Git and Godot imports/exports. Never paste that file into an issue or commit it. If port 8765 is occupied, stop the old bridge in its own Terminal or deliberately use `--port 8766 --config /absolute/path/to/bridge-8766.json`, then choose that same file in both clients. A failed bind does not change pairing files. Godot automatically reloads the local pairing file when disconnected. If using a saved override or an exported viewer, choose the current file in Godot Settings → Voice connection as well.

## 3. Install and pair the extension

1. Open `chrome://extensions` (Edge: `edge://extensions`). Enable Developer mode, choose **Load unpacked**, and select `browser-controller/extension`.
2. In the same browser profile where you already use ChatGPT, open your **Aisora Project and its intended conversation**. Complete normal sign-in, microphone and Voice setup yourself. The extension does not manage authentication or choose a Project. Enter your Project label in the popup; it is a user-selected label, not automatically verified membership. Select the actual conversation, not the home or Project landing page.
3. Pin the Aisora extension to the toolbar and click it while that ChatGPT tab is selected.
4. Choose **Pair / troubleshoot bridge** to open the persistent setup tab, then import `.local/bridge.json`. Wait for **Connected**, which confirms authentication before saving; importing alone is not success. Dot folders are hidden in Finder: use **Command+Shift+G**, paste the full path to `/path/to/Aisora/.local`, then select `bridge.json`.
5. Click **2. Use this ChatGPT tab**. Only this tab and conversation path receive commands; other ChatGPT tabs are ignored. Navigating to another conversation clears the selection and stops capture. Reselect after navigation, restarting the browser or closing the tab.
6. Wait a second and **Refresh status**. Godot should report “Browser connected.” If Chrome asks to access the local network, allow the extension's loopback connection. Permissions are never bypassed.
7. Try Voice **manually in ChatGPT first**. Then test F8 in the Godot window to start, inspect the browser's actual Voice UI, and press again to end. Allow onboarding dialogs or microphone prompts yourself. A missing/changed button produces a diagnostic instead of repeated clicking.

Automation uses exact English accessible labels or a small set of button test IDs. For a localized/changed UI, use manual Voice. Advanced CSS selector overrides in the popup can target the visible start/end buttons; they must each match one control. No credentials or page scripts are required.

Godot F8 requires focus. If macOS maps F8 to media controls, try **Fn+F8**, enable standard function keys in System Settings → Keyboard → Keyboard Shortcuts → Function Keys, or choose F9 in Aisora Settings. The extension shortcut defaults to Command+Shift+8 inside the browser; change it in `chrome://extensions/shortcuts`. Do not bind the same shortcut to multiple helpers.

## 4. Output-audio lip sync

The primary route uses **Chrome's tabCapture**, so **BlackHole is not required**. This captures the selected ChatGPT tab's output instead of your microphone. Your browser continues to send your microphone to ChatGPT under its normal permission.

1. Stay on the selected ChatGPT tab, open the Aisora popup and click **3. Capture this tab's output audio**. Approve any browser/macOS capture prompt. The browser must support tab capture/offscreen documents (Chromium 116+).
2. Start native Voice and ask a short question. You should hear the response once; the offscreen analyzer explicitly reconnects captured audio to your speakers.
3. Aisora's mouth should respond to **ChatGPT's output**, stay closed while only you speak, and close during silence. Adjust Mouth sensitivity and Silence threshold in Settings. Keep noise threshold above any steady output noise.
4. Test that playback is still audible after stopping capture. **Stop output capture** in the popup before closing the bridge; Control+C stops the bridge. Closing Chrome also ends capture. Closing only the popup leaves capture running.

No raw audio is sent to Python or Godot. The analyzer emits RMS amplitude 10 times per second; Godot applies attack/release smoothing and a cap. Browser suspension, stale samples, and disconnects close the mouth. Other audio generated **inside the same tab** can also move the mouth. This is not speaker identification or phoneme-perfect animation.

If Voice detection is unavailable but tab capture works, start Voice manually and choose **Talking (4)** in Godot. That explicit override accepts captured output without requiring DOM state detection. Switch to **0** afterward. The Settings test-mouth toggle is synthetic and clearly marked; turn it off for real use.

Safari/Firefox: manual Voice remains usable with the character, but this extension and its output analyzer are Chromium-specific. macOS Ventura does not expose a general system-audio input through Godot's microphone API. BlackHole 2ch + an Audio MIDI Setup Multi-Output Device (speakers + BlackHole) is a possible alternative: route the browser output there while keeping ChatGPT input on the physical microphone. **A BlackHole input adapter is not implemented or verified here**, so that setup alone does not feed this viewer. Use the implemented Chromium route first. Official alternative reference: https://github.com/ExistentialAudio/BlackHole (GPL-3.0; not bundled).

## Optional global F8

`tools/start_hotkey.command` compiles a tiny native Carbon hotkey helper with Apple's Command Line Tools. It does not monitor all keystrokes or need Accessibility permission. The helper remains one idle process while its Terminal is open; Control+C stops it. It registers F8 system-wide so you can keep the browser on one display and Aisora on the other.

```sh
./tools/start_hotkey.command
# Alternative if F8 is reserved; use one shortcut source at a time:
./tools/start_hotkey.command --alternate
```

The alternative is **Command+Shift+8**. Disable/reassign the extension's equivalent shortcut before using this alternative to prevent duplicate toggles. If Apple tools are absent, `xcode-select --install` installs them; this is optional and much larger than the Aisora code. In-app F8/F9 and the extension button work without the helper. Compilation and event delivery must be checked on your Mac; the Linux cloud cannot validate Carbon.

## Local acceptance checklist

- Character, textures, blink, gentle motion and framing look correct; adjust camera height/distance as needed.
- Test every state with 1–5 and preview all 15 supported standing actions in Settings. Load your preferred first background with the local picker and verify foot placement, aspect scaling, effects off/on and the optional 3D park. Allow 2.4 seconds to settle into sleeping and 1.8 seconds to wake; 0 resumes automatic states.
- Voice starts and ends **twice** through the selected existing Project conversation, without moving the conversation.
- Permission/sign-in dialogs require normal user action; no click loop is started.
- Output is audible once, mouth moves with ChatGPT speech, stays still during your microphone-only input, closes in silence and after capture stops.
- During an active call, switch away from Aisora and minimize its window. Voice should continue, then fresh status/mouth movement should return on restore. Inactive/minimized caps are 10/5 FPS. Close/reopen the bridge and reselect a closed ChatGPT tab to test recovery.
- Test F8/F9, optional global helper, full-screen and the Samsung display locally.
- Watch Activity Monitor for several minutes. Reduce resolution/FPS/quality if needed; 30 FPS is a configurable target, not an iMac benchmark measured in cloud.
