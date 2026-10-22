# Aisora Phase 6 — Intel macOS installation

Built from kingstar3452/Aisora, dev/aisora-companion, commit e3a1c56a0b6f7cff146404b33d3fbc242cc45425.
Target: 2017 Intel iMac / macOS Ventura, x86_64, Godot 4.6.3 Compatibility.

## Run Aisora without Godot

1. Download Aisora-phase6-macos.zip and its .sha256 file from this release. If desired, verify in Terminal from Downloads: `shasum -a 256 -c Aisora-phase6-macos.zip.sha256`.
2. Double-click the ZIP in Finder. Move the extracted Aisora.app into Applications (or your preferred local folder). Keep your working Phase 5 app as a backup.
3. Open Aisora.app. This app is unsigned and not notarized. If macOS blocks an unidentified developer, try Control-click → Open; if needed, attempt launch once and use System Settings → Privacy & Security → Open Anyway for this app. Only approve the app you downloaded and trust. Do not disable Gatekeeper system-wide.
4. Godot is not required. A standard resizable window should open; start with Low graphics, native 3D resolution, 30 FPS. Tab opens Settings; F3 shows performance diagnostics; 15 FPS low-power mode is available.
5. Your existing local settings/imported images remain in Godot's Aisora user-data folder. The first Phase 6 save backs up existing settings as settings-before-phase6.cfg. Do not delete that folder when replacing the app.

The original 3D character, five optimized background images, weather/time-of-day controls, personality gestures and full-body/autonomous animation code are packaged in the app. Calibrated full-body rest and major autonomy are opt-in. In Settings, calibrate a clear virtual floor for each image before walking/resting; no collisions are inferred from painted scenery. Sitting needs 1×2 m and reclining 1.8×2.4 m at unit character scale, with supported seat height 0.48–0.60 m. Conversation takes priority.

## Optional ChatGPT Voice and lip sync

The character runs without a bridge, Python or browser extension. ChatGPT Voice still runs in your normal authenticated browser, separately from the character app.

If your Phase 5/6 bridge and extension already work, keep them. In the standalone app use Settings → Voice connection → Choose bridge pairing file and select the current bridge.json.

Otherwise download Aisora-phase6-voice-bridge.zip from this release and extract it to a permanent writable folder. It includes unchanged bridge/extension sources from the same commit; no Godot or repository checkout is needed.

1. Install Python 3.10+ if needed; no pip packages are required. Double-click tools/start_bridge.command inside the extracted Aisora-phase6-voice-bridge folder. If Finder refuses the downloaded script, open Terminal, `cd` into that folder, and run `bash tools/start_bridge.command`. Keep that Terminal open while using Voice.
2. Chrome/Edge 116+: open chrome://extensions (or edge://extensions), enable Developer mode, choose Load unpacked, and select browser-controller/extension in that extracted folder.
3. In the extension popup choose the newly generated .local/bridge.json. In Finder's file picker press Command+Shift+G to enter the bridge folder's .local path, or Command+Shift+Period to show hidden files. Choose the same file in Aisora Settings → Voice connection. This is a local pairing key, not a ChatGPT credential; do not share it.
4. Open your intended existing Aisora Project conversation in the browser. Enter its Project label and choose Use this ChatGPT tab. The label is user-selected; Project membership is not automatically verified. Keep your normal signed-in browser profile.
5. Start Voice manually in ChatGPT first and approve normal microphone permissions. Use Capture this tab's output audio in the extension for amplitude lip sync, approving normal capture prompts. If automatic Start/End cannot recognize changed/localized controls, use ChatGPT's buttons manually. Re-select the tab and capture after a browser restart.
6. End Voice before switching conversations. No cookies, authentication tokens, transcripts or raw audio are extracted by the bridge. Only output amplitude and connection/control metadata are sent over loopback.

## Validation and limits

Built/exported in Linux using checksum-verified official Godot 4.6.3 templates and their unchanged Intel Mach-O slices. Automated checks, actual-rig simulation, Compatibility rendering and extracted-pack tests are reported in the release notes. ZIP integrity, executable x86_64 architecture/permissions and resources are verified.

The macOS executable has NOT been launched on a Mac here. Ventura launch/Gatekeeper, real microphone/tab capture/playback, authenticated native ChatGPT Voice and sustained iMac performance remain untested. Known cloud performance regressions and an initial standalone stall are documented; a 30 FPS target is not a hardware guarantee. Full cloth collision, arbitrary seats, unrestricted navigation and cinematic mocap are not implemented.

Setup/animation controls/rollback: https://github.com/kingstar3452/Aisora/blob/e3a1c56a0b6f7cff146404b33d3fbc242cc45425/docs/PHASE6.md
Performance evidence: https://github.com/kingstar3452/Aisora/blob/e3a1c56a0b6f7cff146404b33d3fbc242cc45425/docs/PERFORMANCE_PHASE6.md
Licenses/provenance: https://github.com/kingstar3452/Aisora/blob/e3a1c56a0b6f7cff146404b33d3fbc242cc45425/docs/THIRD_PARTY.md
