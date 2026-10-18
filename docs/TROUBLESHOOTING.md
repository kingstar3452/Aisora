# Troubleshooting

| Symptom | Action |
| --- | --- |
| Godot cannot load VRM / character absent | Use Godot 4.6.3 standard, enable both bundled editor plugins, reimport `assets/character/aisora.vrm`. Keep addon directory names unchanged. Inspect the Godot Output/Debugger for import errors. |
| Pink materials | Check the MToon addon is present/enabled; use Compatibility renderer and reimport. Do not delete embedded model textures or substitute arbitrary materials. |
| Character too high/close or off-screen | Tab → Illustrated scenery → Character scale / horizontal position / ground position; camera distance/height still work. Scaling is uniform; the original VRM is unchanged. |
| Broken addon after upgrade | Restore pinned version; see THIRD_PARTY.md for the two local patches. Revalidate on the new engine instead of assuming compatibility. |
| F8 plays media / does nothing | Focus the running viewer, try Fn+F8, choose F9, or use popup Toggle. Godot editor F8 may stop the running project when the editor has focus. Optional global helper requires local Mac testing. |
| Voice is “unknown” | Open the correct signed-in ChatGPT tab, select it with the extension, refresh. Native controls may be localized or changed; use manual Voice or specific advanced CSS selectors. Dictation is deliberately not treated as Voice. |
| “Voice command timed out” | Inspect ChatGPT for onboarding/microphone/login prompts. Complete them manually. Confirm the Voice controls exist. Do not repeatedly toggle while a command is pending. |
| Bridge unavailable / 401 | Start `tools/start_bridge.command`, choose its current pairing file in both the extension and Godot Settings → Voice connection, and reselect the same tab. No ChatGPT login secret is needed. Changing/removing `.local/bridge.json` invalidates the old local pairing. |
| Cannot connect / blocked local-network access | Approve the browser's normal local-network/extension permission if prompted. The bridge listens only on 127.0.0.1; do not expose it on a LAN or disable browser security. |
| Address already in use | Stop an earlier bridge or start with `--port 8766`, then re-pair. |
| Mouth stays closed | Turn off synthetic test mode. Start tab output capture from the selected ChatGPT tab; verify browser permission, Voice active state and output sound. If DOM detection is unavailable, use Talking (4) while manually controlling Voice. Increase sensitivity gently. |
| Mouth moves while you speak | Confirm only ChatGPT tab output is captured. Check for microphone monitoring/echo or other audio in that tab. This code does not capture the microphone, but it cannot remove echo already present in output. |
| Audio is silent after capture starts | Stop capture to restore normal tab audio. Retry from the active ChatGPT tab and inspect extension errors; the offscreen AudioContext may have been denied/suspended. Do not mute the tab. |
| Audio doubles | Ensure only one Aisora extension/capture/helper instance runs. Do not simultaneously monitor the output through another routing utility. |
| Listening remains after a call/disconnect | A known active session conservatively blocks idle actions across lost metadata. End Voice manually, then use **Voice ended manually · resume idle actions** in Godot. The equivalent popup recovery clears tab ownership. Neither button ends a browser call. Do not use them while Voice is active. |
| Voice metadata is unknown/stale | Keep the selected ChatGPT tab open and avoid Memory Saver suspending it. Use ChatGPT controls manually and presentation states 2/3/4 if detection is unavailable. Live Voice/output capture still need local testing. |
| High CPU or warm iMac | Enable Low-power mode (15 FPS), Low graphics, lower petal density/resolution; inspect F3 mean/p95 frame times; close unused browser tabs. Inactive/minimized rendering caps at 10/5 FPS. Springs/shadows/postprocessing remain disabled. No thermal protections are changed. |
| Motion too busy or too subtle | Adjust Animation intensity (default 1.00). Preview each idle gesture from Settings. Blink and output-driven mouth weights remain independent. Sleep is a standing resting pose; allow its transition to finish. |
| Voice status drops when minimized | Use the current development branch so the Godot HTTP client uses worker threads. The local 5 FPS integration test passes; native macOS background/browser behavior still needs local checking. Keep the bridge Terminal and selected browser tab open. |
| Preferred picture is absent | Save your permitted first image locally, then Tab → Illustrated scenery → Choose local park image. The cloud had no downloadable attachment pixels; the bundled illustration is original placeholder art. |
| Image fails to load / transparent foreground rejected | Use PNG/JPEG/WebP, at most 20 MiB / 16 megapixels / 8192 pixels per edge. Foreground needs an alpha channel with actual transparency. An invalid replacement retains the existing scenery. |
| Image is cropped | Cover scaling preserves proportions and fills the window by cropping edges. Resize the window or choose a similar-aspect image; adjust Aisora's foot anchor separately. |
| Sitting, walking or lying preview is absent | These transitions are deliberately unavailable until convincing foot/seat/floor contact and clothing can be validated. Sleep/wake currently means standing rest. |
| Long gesture does not preview | Active, pending or uncertain Voice blocks long idle actions. Finish the call first. After a confirmed manual end, clear a stale guard if necessary. |
| Extension is still on old behavior | End an active call before reloading extension 0.2.0, then refresh the same conversation tab and select it again. Never update during a live call. |
| Capture denied or ended | Retry output capture explicitly from the selected tab after allowing normal browser permissions. For microphone errors, allow ChatGPT site access and browser microphone access in macOS settings. Voice remains controllable manually. |
| Settings seem stuck | Close the viewer, remove only its local `settings.cfg` in `~/Library/Application Support/Godot/app_userdata/Aisora/`, then restart. Never remove model/project files to reset preferences. |

To shut down: end native Voice in ChatGPT, stop output capture in the extension, close the viewer, and Control+C the bridge/optional global-hotkey Terminal. Browser authentication remains entirely with the browser. Closing Godot alone does not end an ongoing ChatGPT Voice session.

For a report, include engine/browser versions, operating system, exact visible error and which milestone fails. Do not attach pairing keys, cookies, account data or conversation transcripts.

## Phase 5 scenery, motion and performance

- Wrong time image: check **Local time & image slots**, manual override, the Mac clock/timezone and the ordered start hours. Default boundaries are 06:00 / 12:00 / 17:00 / 20:00. Rain overrides the time choice; select Clear to return. An active short-step sequence defers image changes until it returns home, including while Voice holds it.
- Missing or unchanged picture: Settings explains whether a file is missing/loading. The existing valid image and light are retained. Assign a valid PNG/JPEG/WebP or restore the supplied sunset. **Use previous local sunset** preserves the old file; do not erase the application-data folder during an upgrade.
- Rain remains with the animated layer off: the supplied rainy image itself contains painted rain. Choose Clear for the time-of-day background. Petals, rain/cloud/fog layers each have separate controls. Background branches cannot be individually animated without separate alpha artwork.
- Steps disabled: calibration is per slot and exact image file. Use the visible virtual-ground rectangle, place Aisora on clear ground, confirm calibration and end Voice before previewing. The supplied artwork has no inferred obstacle map. Seating, floor rest and long walking are unavailable.
- Lag: start Low, native LOD enabled, lower petals/weather, then try **3D render resolution 0.75**. F3 shows actual dimensions and frame times. Optional adaptation reduces resolution after sustained slow frames. Compare outside the editor; 15 FPS low-power is available. Neither setting guarantees iMac performance.
- UI hidden: Tab restores Settings from clean mode; H toggles clean presentation. Connection details and manual Voice buttons are at the top of Settings. High uses original MToon and ignores the Low/Balanced contrast slider.

See [Phase 5 acceptance checks](PHASE5.md) for installation, saved imports, crossfades and target-Mac limitations.
