# Phase 6 setup and acceptance

Phase 6 adds calibrated full-body motion, opt-in autonomy and ten authored personality gestures to the working Phase 5 viewer. The original VRM, five supplied illustrations, local sunset alternatives, weather, clock, lighting, voice bridge and performance controls remain. **Start with Low, native 3D resolution, 30 FPS.** Full-body rest and major-action autonomy default off. Existing standing actions continue without floor calibration.

## Install and preserve the working version

Use Godot **4.6.3 standard / Compatibility** and the existing `dev/aisora-companion` checkout. Open `project.godot`, allow import to finish, then Run Project. See [Mac setup](SETUP_MAC.md) for the Python 3.10+ standard-library bridge and Chromium 116+ extension. No paid API, motion pack, extra runtime service or dependency is required.

On the first Phase 6 settings save, the viewer copies existing `settings.cfg` to **`settings-before-phase6.cfg`** beside it. It never overwrites that backup. If copying fails, preferences remain in memory and the old file is preserved. Imported images are untouched. Godot's macOS user folder is normally `~/Library/Application Support/Godot/app_userdata/Aisora/`; open it through the editor's user-data-folder command if yours differs.

For a standalone Intel Mac test app, run the optional export setup below. A cloud-built unsigned Intel app is also provided with the implementation delivery; see its [build record and checksum](BUILD_PHASE6.md). Extract the ZIP, move `Aisora.app` to your chosen folder and launch it using macOS's normal approval for a trusted unsigned app. Do not disable system-wide security settings. The bridge and browser extension still run separately from the source checkout; in the exported viewer choose `.local/bridge.json` under Settings → Voice connection. **Export succeeds in Linux; launch, Gatekeeper, sound and native Voice on Ventura still require your local test.** The source/editor path remains available if the app is unsuitable.

```sh
# Optional development export, not required to run from the editor.
# Downloads ~1.26 GB of official templates once; verifies pinned SHA-256.
python3 tools/prepare_export_templates.py
mkdir -p exports
python3 tools/export_macos.py --output exports/Aisora.zip
```

The helper retains only matching Mac/Linux templates and prepares an Intel-only template from the unchanged Intel Mach-O slices in the verified official universal archive. This avoids requesting ARM texture imports on the working Intel project. Binaries/templates stay ignored. No ARM Mac support, signing or notarization is claimed. Engine notices accompany exported builds; source provenance is in [THIRD_PARTY.md](THIRD_PARTY.md).

## Calibrate the virtual floor first

Open Settings with **Tab**. Under the existing ground controls, set Aisora's anchor/scale, enable the guide, set a clear ground rectangle and confirm calibration for the **currently displayed image**. Painted benches, paths and trees are illustrations; they have no inferred collisions or seat surfaces. Calibration is saved against that exact local image/slot. Replacing an image invalidates its old calibration.

Four-direction walking uses three short steps out and three back, with independent hip/knee/ankle motion, lifted swing feet, planted stance targets and arm swing. Forward/back/sideways, pacing and 15–90° step turns are bounded and return to the original anchor. Individual steps are at most 18 cm at unit scale. Very small rectangles refuse actions rather than silently crossing the boundary. The legacy short-step controls remain; their default turn is 25°.

Under **Phase 6 · full-body & personality**, enable the calibrated virtual seat/floor controller. At unit character scale, sitting needs **1.0 × 2.0 m**, reclining/sleeping **1.8 × 2.4 m** of clear floor. Requirements scale with the character. The supported virtual seat surface is **0.48–0.60 m** high. The optional settings guide marks a virtual seat; no chair is added to the illustration and no painted bench is claimed to match it. Use a separate supplied foreground/seat layer or the optional 3D scene if you need a visibly grounded chair.

Choose **Sit**, **Lie down**, **Sleep**, or **Stand / wake and return**, then Play. Sitting takes about three seconds; reclining adds about four. Getting up reverses the supported contacts before a standing stretch. Hips and spine articulate separately from legs/arms; the model root is translated, never simply tipped over to fake lying. Sleeping closes the eyes, slows breathing and occasionally changes head/hand/heel posture slightly. A gentle camera orbit during reclining makes the pose readable and restores your exact standing framing afterward. Position/camera/calibration edits and image/weather transitions wait for a safe standing return.

Return to standing is always available. A conversation requests a safe get-up, with listening/speaking face and head layers live during that transition. It does not snap the whole body upright or start a new idle action during Voice.

## Personality and autonomy

The manual Phase 6 selector provides **unimpressed arm crossing, playful eye rolling, smirking, dramatic head turning, mock annoyance, amused laughter, curious head tilting, exaggerated disbelief, playful finger pointing, and confident hand-on-hip poses**. These are reusable authored poses on the actual skeleton and facial morphs. Their facial-expression intensity is independent of the overall animation slider. Laughter is a silent grin/eye/head/shoulder gesture; it does not invent audio or drive the `aa` speech morph. The fold is deliberately loose to respect the wide clothing.

Enable **Autonomous major actions** to add weighted local selection. Set interval minimum/maximum (defaults 45–120 seconds), major-action weights and individual personality weights. Zero removes a choice. Movement waits for calibrated space; rest also requires its opt-in. Recent actions are avoided when alternatives exist, with 90-second movement/gesture and 300-second rest cooldowns. One remaining choice can repeat after its cooldown. Night favors rest and permits sleep; morning favors stretching. Autonomous rest holds for 45–90 seconds, then returns. The existing standing micro-movement scheduler supplies breathing, blinking, gaze, posture and small gestures between actions. Leave the separate optional standing night-rest toggle off if you want the new major scheduler to choose floor rest instead.

Voice, pending commands, uncertain ongoing sessions, image fades and active transitions take priority. New major actions wait at least eight seconds after Voice activity. During a call the current walking foot lands before movement holds, or rest gets up safely. No sleep or pacing is selected during a conversation.

**No emotions are inferred from ChatGPT text, tone or amplitude.** Personality is subtle context-independent idle expression or a manual preview after Voice ends. ChatGPT Project instructions remain responsible for conversational personality; the viewer does not rewrite them.

## Pair the intended ChatGPT Project conversation

1. Start `tools/start_bridge.command` (or `python3 browser-controller/bridge.py`). Keep the existing authenticated Chrome/Edge profile.
2. Reload the unpacked extension after updating to **0.3.0**, then refresh the intended existing ChatGPT conversation tab. Do not sign out. Choose the bridge pairing file in the popup if necessary.
3. Open the actual conversation inside your Aisora Project. Enter the Project label and choose **Use this ChatGPT tab**. Conversation URLs are accepted; home and Project landing pages are refused. The label is explicitly user-selected, **not proof of Project membership**. No tab navigation, new conversation, cookies, authentication tokens or undocumented auth endpoints are used.
4. From that tab, use **Capture this tab's output audio** for amplitude lip sync. This requires a browser user gesture/permission and may need repeating after a browser restart. Only scalar RMS goes to the bridge; microphone audio, transcripts and raw recordings do not.
5. Start/end Voice in ChatGPT manually first. Popup/Godot Start, End and Toggle are optional automation when visible controls can be identified unambiguously. If the page changes/localizes controls, set explicit visible selectors or keep using manual controls. Do not click a second Start while an existing call is active.

The selected conversation survives extension-worker restart in that browser session; a browser restart requires explicit tab reselection. Reconnection retains the binding, cancels stale commands and rejects old-binding amplitude. Selecting a different tab is blocked while a call is observed or pending. The clear-stale-guard control is for a call you have **already ended manually**. It is not an automatic retry that starts another Voice session.

Godot reports bridge/browser freshness, detected Voice state and your Project label. Output amplitude drives Speaking and mouth motion. A visible thinking/listening marker is used only when present; otherwise active Voice with no output is a coarse attentive state, **not proof that the microphone is receiving you**. Permission errors are reported without requesting credentials. Browser suspension/missing controls remain possible. Native authenticated ChatGPT Voice, physical output capture and permission handling are **not certified on your Mac** by simulated browser tests. See [Mac setup](SETUP_MAC.md) for permissions and manual fallback.

## Limits of this rig and implementation

These are conservative procedural motions on the original rig, not cinematic captured clips. Rest uses a supported upright sit and a supine bent-knee recline. Arbitrary seat heights, deep benches, cross-legged sitting, side-lying, full sleeping rolls, unrestricted navigation and 360° turns are not implemented. The long skirt, hair and fox tail require rig-specific corrective bone poses. Sampled skinned floor/bounds checks and multiple rendered angles reduce obvious problems; they do not constitute a full cloth/body triangle collision solver or guarantee every camera, intensity and replacement outfit is clipping-free. Avoid low foot-end camera angles for the dress; the reclining camera orbit addresses the default view.

For higher-quality motion, author contact-constrained clips and skirt/tail corrective shapes in Blender on this exact VRM rig, then export glTF 2.0 with matching humanoid axes. A properly licensed compatible mocap clip would need retargeting and clothing correction, not just root rotation. No unlicensed clip or new animation runtime is bundled.

## Local acceptance and rollback

- Start with your existing Phase 5 settings and all five image slots. Check the local sunset alternative is still selectable, clock/manual selection and rain override still work, and crossfades preserve aspect ratio.
- On Low/native with F3 visible, observe several minutes idle, talking, four walking directions, turns, sit/recline/sleep/get-up and all ten personality previews. Inspect hands, skirt, tail, feet and camera return. Try 15 FPS low-power, resize, inactive/minimized and your normal display setup.
- Enable major autonomy only after calibration. Observe a longer day/night session; interrupt movement and sleep with real Voice. Check no new sleep/pacing during the call, feet land and rest gets up smoothly.
- Pair the intended Project conversation; test manual and automatic Start/End, deny microphone/capture once, restore permission, restart bridge, reload tab and extension worker, then restart browser/reselect. Confirm one call, audible playback, mouth only on tab output and no stale motion after silence. Test another-tab selection refusal during a call.
- Compare editor and exported app under the same Mac preset/window size. Record FPS/frame-time spikes and Activity Monitor CPU/memory over 10–15 minutes. Cloud measurements in [PERFORMANCE_PHASE6.md](PERFORMANCE_PHASE6.md) do not predict Intel Mac thermals or driver behavior.

Rollback: quit the viewer/bridge; keep your current folder, and open a separate checkout/archive of Phase 5 commit **`e04341e849834adb480549f17ef57e581e1314e3`**. Copy `settings-before-phase6.cfg` over `settings.cfg` in the same user-data folder if you want exact former preferences. Leave imported image files in place. Reload the old extension from that checkout and reselect its conversation/capture as needed. Do not reset/delete your working directory or ChatGPT session. P6 settings sections are additive, but restoring the backup also restores old calibration limits.

[Validation records](TEST_RESULTS.md) distinguish automated rig/browser fixtures, Linux OpenGL rendering, export structure and untested Mac behavior.

## Actual-rig visual review

Personality sheets: [front](images/phase6-personality-0.png), [left](images/phase6-personality--65.png), [right](images/phase6-personality-65.png). Each uses catalogue order, left to right, five columns/two rows: unimpressed, eye roll, smirk, dramatic turn, mock annoyance; laughter, curious tilt, disbelief, pointing, hand-on-hip. These are peak samples; playback includes eased entry/exit. Clothing-safe loose poses can be less exaggerated than a motion-capture performance.

Rest transitions: [front](images/phase6-rest-0.png), [left](images/phase6-rest--65.png), [right](images/phase6-rest-65.png). Rows are sit, recline, sleep; columns are 1, 2, 3, 4, 5, 6, 7.33 and 10 seconds. The gray floor is a developer guide, not a generated collision map for the illustration. [Walking forward](images/phase6-walk-forward.png) and [sideways](images/phase6-walk-left.png) show lifted/planted feet and return from three angles. The development capture helper produces equivalent sheets for all nine movement choices. [Default reclining camera](images/phase6-recline.png) shows the actual image composition.
