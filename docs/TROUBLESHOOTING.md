# Troubleshooting

| Symptom | Action |
| --- | --- |
| Godot cannot load VRM / character absent | Use Godot 4.6.3 standard, enable both bundled editor plugins, reimport `assets/character/aisora.vrm`. Keep addon directory names unchanged. Inspect the Godot Output/Debugger for import errors. |
| Pink materials | Check the MToon addon is present/enabled; use Compatibility renderer and reimport. Do not delete embedded model textures or substitute arbitrary materials. |
| Character too high/close or off-screen | Tab → Camera distance/height. The model's authored scale is meters; import scale remains 1.0. |
| Broken addon after upgrade | Restore pinned version; see THIRD_PARTY.md for the two local patches. Revalidate on the new engine instead of assuming compatibility. |
| F8 plays media / does nothing | Focus the running viewer, try Fn+F8, choose F9, or use popup Toggle. Godot editor F8 may stop the running project when the editor has focus. Optional global helper requires local Mac testing. |
| Voice is “unknown” | Open the correct signed-in ChatGPT tab, select it with the extension, refresh. Native controls may be localized or changed; use manual Voice or specific advanced CSS selectors. Dictation is deliberately not treated as Voice. |
| “Voice command timed out” | Inspect ChatGPT for onboarding/microphone/login prompts. Complete them manually. Confirm the Voice controls exist. Do not repeatedly toggle while a command is pending. |
| Bridge unavailable / 401 | Start `tools/start_bridge.command`, choose its current pairing file again, and reselect the tab. No ChatGPT login secret is needed. Changing/removing `.local/bridge.json` invalidates the old local pairing. |
| Cannot connect / blocked local-network access | Approve the browser's normal local-network/extension permission if prompted. The bridge listens only on 127.0.0.1; do not expose it on a LAN or disable browser security. |
| Address already in use | Stop an earlier bridge or start with `--port 8766`, then re-pair. |
| Mouth stays closed | Turn off synthetic test mode. Start tab output capture from the selected ChatGPT tab; verify browser permission, Voice active state and output sound. If DOM detection is unavailable, use Talking (4) while manually controlling Voice. Increase sensitivity gently. |
| Mouth moves while you speak | Confirm only ChatGPT tab output is captured. Check for microphone monitoring/echo or other audio in that tab. This code does not capture the microphone, but it cannot remove echo already present in output. |
| Audio is silent after capture starts | Stop capture to restore normal tab audio. Retry from the active ChatGPT tab and inspect extension errors; the offscreen AudioContext may have been denied/suspended. Do not mute the tab. |
| Audio doubles | Ensure only one Aisora extension/capture/helper instance runs. Do not simultaneously monitor the output through another routing utility. |
| Idle is shown during an active call | Browser heartbeat may be stale/throttled. Keep the selected ChatGPT tab open and avoid browser Memory Saver suspending it. Live Voice and output capture must be tested locally. |
| High CPU or warm iMac | Low power quality, lower FPS/resolution, disable synthetic test, sleep when not used; close unused browser tabs. Springs/shadows/postprocessing are already disabled. No thermal protections are changed. |
| Settings seem stuck | Close the viewer, remove only its local `settings.cfg` in `~/Library/Application Support/Godot/app_userdata/Aisora/`, then restart. Never remove model/project files to reset preferences. |

To shut down: end native Voice in ChatGPT, stop output capture in the extension, close the viewer, and Control+C the bridge/optional global-hotkey Terminal. Browser authentication remains entirely with the browser. Closing Godot alone does not end an ongoing ChatGPT Voice session.

For a report, include engine/browser versions, operating system, exact visible error and which milestone fails. Do not attach pairing keys, cookies, account data or conversation transcripts.
