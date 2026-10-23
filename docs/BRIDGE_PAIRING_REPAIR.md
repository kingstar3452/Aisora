# Bridge pairing repair — 0.3.1, protocol 1

**Keep the working Aisora 6.1.0-rc.2 app. No desktop rebuild or reinstall is required.** This update replaces only the Python bridge and Chrome extension. The user reports that the standalone app launches on the Ventura iMac; actual repaired pairing/Voice still requires their local test. No stable release or native Voice success is claimed.

## Confirmed defect and other failure paths

The old bridge wrote/replaced `bridge.json` **before binding its port**. A second source folder could generate a fresh key for port 8765, fail because the original bridge still owned that port, and leave a valid-looking file that the original process rejects. Two regression tests reproduced the file creation/overwrite on failed startup. Reimporting that JSON cannot fix the key/process mismatch. Bridge 0.3.1 reserves the port first and preserves existing configuration bytes on failure.

The old extension returned authentication errors through popup messages, so an empty service-worker Console did not prove pairing succeeded. Its short-lived popup owned the native file picker, and selecting the same file again did not reset the input. The new **persistent setup tab** avoids popup-lifetime dependence and clears the file input after every attempt. Native macOS picker teardown is a possible failure path, not a confirmed reproduction on the user's Mac. The encountered extension **0.1.0** is an observed component mismatch; use exactly **0.3.1** below. The actual cause on the iMac remains to be confirmed by the new diagnostics.

## One repair folder and one running bridge

1. End ChatGPT Voice and stop output capture. Leave the working app installed. Stop old bridge processes with **Control+C in their own Terminals**; do not kill unrelated Python processes or clear browser data.
2. Download **Aisora-bridge-extension-0.3.1.zip** from the **private v6.1.0-rc.2 draft** in [official repository Releases](https://github.com/kingstar3452/Aisora/releases). Owner login is required. The final [delivery receipt](bridge-repair-delivery.json) records exact URLs/SHA-256. Extract it once and keep its contents in one canonical folder, for example **~/Documents/Aisora Support**. `COMPONENTS.json` records exact versions, source commit and per-file hashes. No pairing file/key is shipped.
3. In Terminal, enter that folder (it contains `browser-controller` and `tools`) and start a single bridge with a visible, stable configuration path:

```sh
cd "$HOME/Documents/Aisora Support"
python3 browser-controller/bridge.py --config "$HOME/Documents/Aisora Bridge/bridge.json"
```

The bridge uses Python 3.10+ standard library; no pip packages, Go or Godot are needed. The console must say **bridge 0.3.1 / protocol 1**, print the running source path, and print that exact configuration path. The file is private and its key survives restart. Existing default `.local/bridge.json` remains supported; the visible path simply avoids multiple hidden copies. Do not regenerate/delete keys to diagnose a connection.

If port 8765 is occupied, the bridge now stops clearly **without writing/replacing the pairing file**. Find/stop the old bridge in its own Terminal. Alternatively deliberately use `--port 8766 --config "$HOME/Documents/Aisora Bridge/bridge-8766.json"` and select that same file in both clients. Do not assume that a listening-port message in another Terminal belongs to the source copy you just extracted.

## Load the matching extension and authenticate

4. Open `chrome://extensions`. Disable old duplicate Aisora extensions, especially **0.1.0**. Use **Load unpacked → ~/Documents/Aisora Support/browser-controller/extension**, the folder containing `manifest.json`. Confirm **0.3.1** in Details. If updating the same loaded folder, use **Reload** after copying the new extension files there. Loading a different folder can give a new extension ID and requires one new pairing import; Chrome sign-in/ChatGPT authentication is unaffected.
5. Open the extension popup → **Pair / troubleshoot bridge**. This opens a persistent setup tab. Import `~/Documents/Aisora Bridge/bridge.json` once. File reading is followed by identity/protocol and authenticated-state checks **before** credentials are saved. Do not interpret file import as success until it says **Connected**. The page displays extension version, bridge version/protocol and endpoint, never the key. **Reconnect** rechecks saved credentials without importing again or starting Voice.
6. Return to the actual existing ChatGPT Project conversation, refresh it after the extension update if necessary, then popup → **Use this ChatGPT tab**. Project landing/home pages cannot be selected. **Connected** describes bridge authentication; **Tab connected/disconnected** is a separate status. Only the explicitly selected tab/path receives Voice commands. Browser restart/extension reload can require explicit tab selection again; saved bridge pairing remains in Chrome local storage when the extension ID is retained.
7. In the already-working Aisora app, Settings → Voice connection → choose the **same exact JSON file**. This updates the old-source-folder/port reference without rebuilding the app. Reusing an old app selection can leave it polling another still-running bridge. Its settings remain saved outside the app.
8. Start Voice manually in ChatGPT first. Select **Capture this tab's output audio** if using lip sync and approve only normal browser prompts. Confirm the app's mouth follows output rather than microphone-only speech. Automation remains best-effort; no cookies, credentials or transcripts are read, and no new session is automatically started.

## Safe independent diagnostic

In another Terminal in the repair folder:

```sh
python3 browser-controller/bridge.py --diagnose --config "$HOME/Documents/Aisora Bridge/bridge.json"
```

This is **read-only**, proxy-free/localhost-only, refuses redirects and prints no pairing key. It checks public service identity/protocol and then authenticates `/v1/state`. `Connected` with `conversation_connected: false` means key authentication worked and the conversation has not supplied fresh heartbeats yet. Exit 0 means authenticated; exit 2 means the report identifies a failure. Never paste `bridge.json` or screenshots of its contents.

| State | Meaning / next action |
| --- | --- |
| Unpaired | No saved/valid file. Import the file printed by the running bridge. |
| Connecting | Identity/authentication probe is in progress; file is not yet saved. |
| Connected | Key authentication succeeded, even if no conversation is selected yet. Select the intended tab separately. |
| Authentication failed / HTTP 401 | The process on this port rejected this key. Match the running source/Terminal/config; check for an older bridge. Reconnect after correcting the file. |
| Bridge unavailable | Process stopped, wrong port, timeout, denied Chrome local-network access or HTTP failure. Start one matching bridge/check normal Chrome permissions and Reconnect. Do not disable security. |
| Incompatible / Invalid configuration | Wrong service/protocol, malformed file or stale storage. Use the matching 0.3.1 components; legacy key/port-only protocol 1 files remain supported. |

**Reset pairing** forgets only the extension's pairing/selection and stops its output meter; it does not delete bridge files, rotate keys, sign out of ChatGPT or end native Voice. End Voice first and confirm the dialog. Known active/pending Voice prevents reset. If Voice ended manually but its conservative guard remains, use the popup's existing **Voice ended manually · clear stale guard**, then reset. Failed imports preserve previously saved pairing. CSS selector preferences remain.

## Verification and limitations

The retained desktop protocol is **1** with unchanged key/port and `/v1/*` contracts. Bridge and extension are **0.3.1**; new metadata is additive. Tests: **25 Python**, **41 Node groups** including real worker→Python HTTP pairing/restart/stale-key/routing, actual Chromium setup DOM/file-picker/retry/reset with mocked extension transport, retained simulated Voice DOM smoke, **15 Godot/HTTP/lip-sync checks using the existing rc.2 PCK**, and the targeted updater Voice-guard test with new metadata. The standalone `.app`, character, shaders, animations, backgrounds and installed browser session are untouched.

Cloud Chromium policy prevents loading the real unpacked extension; that policy was not bypassed. Browser tests use an isolated profile and no authenticated ChatGPT account. On the actual iMac, verify pairing once, close/reopen the popup, reload the extension in the same folder, restart the bridge with the same file, Reconnect/reselect the intended conversation, then test real Voice/audio. Unknown browser state is not assumed safe. Future in-app updates retain their native integrity/Gatekeeper checks.

If pairing still fails, report the **secret-free diagnostic output**, extension version, displayed bridge state/version/endpoint, and whether the selected conversation shows connected. Do not share keys, authentication material, pairing files or unrelated browser contents.
