# Phase 5: illustrated living world

Continue on `dev/aisora-companion` with Godot **4.6.3 standard / Compatibility**. Open `project.godot`, finish import, then Run Project. The default is a normal resizable window, Low graphics, native rendering and a 30 FPS cap. No new runtime dependency or paid API is added. Existing Phase 4 bridge/extension installations need no update or re-pairing for this change. New installations follow [SETUP_MAC.md](SETUP_MAC.md).

The original VRM, skeleton, textures, facial bindings, browser controller, local Voice session and previous preferences are preserved. The optional procedural 3D park remains selectable with its original warm daylight; the new image/time/weather composition is intended for illustrated mode. The new default uses the actual five images supplied in `Aisora_5_High_Quality_Backgrounds (1).zip`, with Aisora rendered fully in 3D in front.

## Images, clock and weather

| Supplied source | Settings slot | Default Mac local time |
| --- | --- | --- |
| `morning.png` | Morning | 06:00–11:59 |
| `afternoon.png` | Daytime | 12:00–16:59 |
| `sunset.png` | Sunset / evening | 17:00–19:59 |
| `night.png` | Nighttime | 20:00–05:59 |
| `rain.png` | Rain | Overrides the time slot during light/heavy rain |

Tab opens Settings. **Local time & image slots** offers automatic system-local time, manual time selection, five independent image pickers, configurable ordered start hours and a crossfade duration (default eight seconds). Changes in the Mac clock/timezone are picked up without restarting. Images cover the window with preserved proportions: window shapes may crop edges, never stretch the picture. Character scale and horizontal/vertical placement remain independent.

The supplied WebP files total **2,727,414 bytes**, down from 16,743,232 source PNG bytes, using quality 90 compression, without recoloring or invented scenes. Their original 1672-pixel width is retained; height is 941 except sunset 940. [The manifest](../assets/world/manifest.json) records each input checksum and dimensions. Runtime Low/low-power textures have a 1280-pixel longest edge; Balanced 1600; High up to 1920 (no upscaling). Only the current image and, during a fade, the next image are uploaded. Clock-driven decoding runs on a worker; GPU texture installation remains on the main thread. First import, image assignment, texture upload and a graphics-preset change can still cause a brief one-off stall.

The previous `environment/background_path` is migrated to **Use previous local sunset** without modifying or deleting its file. **Use supplied sunset image** switches back. Each new private import gets a unique filename; older copies are retained. All assignments and the alternative path persist in `user://settings.cfg`; the copies live in Godot's local application data. On macOS this is normally `~/Library/Application Support/Godot/app_userdata/Aisora/`. Do not delete this directory to upgrade. Existing files are not synced or uploaded.

Missing/invalid images retain the currently displayed image **and its matching character lighting**, with a message in Settings. No blue-tinted sunset substitutes for a missing night picture. The original placeholder is used only when no valid image remains at startup. Lighting color, energy and ambient contribution crossfade with the visible picture. Settings also provide character brightness, color matching, contact-shadow opacity/softness and Low/Balanced contrast. High retains original MToon shading; its contrast slider has no effect.

Weather is manual: Clear, Cloudy, Light rain, Heavy rain, Windy, Misty. Rain uses the separate supplied rainy background even with a manual time override. Returning to clear restores the latest clock/manual slot. Animated rain, clouds and fog have independent switches and a strength/off control. Petal density and environment intensity remain independently adjustable. Wind speeds up the petal layer. Low heavy rain uses at most 64 instanced streaks; low-power at most 24. Sparse optional fireflies appear only with an actual night image. No weather service, location access or storm flashes are used.

The rain artwork already contains static rain; turning its animated layer off cannot remove pixels painted into that image. Stars and lantern glow in the night artwork are static. Optional branch/leaf sway affects only separate transparent foreground art (or the separate original decorative branch), never objects baked into a background. Ambient variation is very slight; optional parallax translates the image without warping it and defaults off. Shader clocks pause in the background without catch-up simulation.

## Actions and grounded steps

The 15 standing actions remain in the Settings catalogue. Arm folding now uses a forward-hands approach and a loose fold in front of the torso. Shoulders, elbows, wrists and finger curls were adjusted against the actual VRM. Replacement actions fade out before the next starts. Breathing, blinking, gaze and appropriate state motion continue. A lightweight cached skeleton calculation checks coarse torso/head/skirt proxies during gestures; an unsafe arm candidate holds its last safe rotation. **This is approximate pose protection, not full mesh, cloth or hair collision detection.** All 15 actions were rendered [front](images/phase5-actions-front.png) and at [55°](images/phase5-actions-side.png) / [−55°](images/phase5-actions-other-side.png); sampling cannot prove every possible layered pose is collision-free.

**Virtual ground · short steps** adds opt-in forward/back steps, short forward/back pacing and left/right **25° step turns**, each returning home. These use actual hip/knee/ankle articulation, lifted swinging feet, planted stance targets, arm swing and bounded root motion. The [pacing audit](images/phase5-ground-pace.png) shows sampled articulated poses on a developer-only flat ground. This is a small procedural stepping system, not polished unrestricted walking or motion-captured locomotion.

1. Place and scale Aisora over a visibly clear region of the chosen image.
2. Open Settings, enable **Show virtual ground boundary**, and adjust its width/depth. Inspect the projected rectangle and the character's full skirt clearance against the picture.
3. Confirm **I calibrated clear ground for this image**, then preview each short sequence. Keep a margin around painted obstacles. Calibration is specific to both the slot and exact file path; replacing the image disables that calibration.
4. Optionally enable occasional idle steps. They occur only after a long idle interval in morning/daytime, with valid calibration and no conversation or image transition.

The picture has no reliable object/depth map. The application cannot infer a bench, building, cliff or foreground obstacle from painted pixels. The supplied mountain/temple scenes do not establish a walkable surface at the default anchor, so movement is **disabled by default**. Bounds and a body margin reject sequences that cannot fit. Calibrate conservatively; leave stepping disabled when no suitable surface exists.

An active or pending Voice conversation prevents new movement. If Voice starts during a step, the current swinging foot lands, then further steps wait; return steps resume after the call. **Image changes, including a rain override, wait until an active step sequence returns home**, so a paused call can defer scenery changes. Placement/camera changes also apply after stepping. Breathing, blinking and attentive/talking animation remain active during the hold.

Sitting, lying, changing floor-rest poses, rising from a seat/floor, full 360° turns and long-distance walking remain unsupported. They are not simulated by rotating or sliding the whole model. The retained sleep/wake is a standing rest, not bench seating. Optional idle night rest defaults off and gives Voice priority; morning can queue a gentle stretch after waking. Time/weather alter idle action weights and gesture pace locally, without an AI service. Quiet original synthetic birds/wind/crickets are optional, silent by default and duck to silence during a conversation; they are not field recordings.

## Performance and interface

Low/Balanced/High, 30 FPS foreground and optional 15 FPS low-power remain. Inactive rendering caps at 10 FPS; minimized at 5 FPS, with 3D draws suppressed. The bridge keeps processing and no Voice stop command is sent. Secondary hair/eye motion remains 8/12 Hz (4 Hz inactive). Unchanged native skeleton/morph writes and unchanged pose conversions are cached; pose checking runs only while a gesture is active or settling. Body/hair native mesh LOD is optional and reversible; the face keeps its original LOD bias and facial bindings.

**3D render resolution** below 1 enables a transparent SubViewport sharing the original world and character. The main camera stops drawing the character, so there is no duplicate model/render. Background and UI remain at native resolution. Reduced modes also cap the 3D texture's longest edge at 1280, useful on a Retina window. Native 1 bypasses that cap. F3 shows the actual reduced dimensions, frame-time mean/p95, draw calls, preset and requested scale. Optional adaptive resolution is off by default: sustained slow foreground frames reduce only rendering resolution with cooldowns, never the FPS target. It does not continually raise/lower quality or react to inactive/settings/import intervals.

The large title/subtitle and normal top-right status are removed. A small Settings button remains, with an issue marker/tooltip on connection errors. Voice status and recovery controls are near the top of Settings. **H** toggles clean presentation; **Tab** restores Settings. F3 toggles diagnostics. Numeric shortcuts do not change animation test states while editing a text/number field. F8/F9, manual Voice start/end and output-amplitude lip sync are preserved. Browser controls remain separate from rendering; no credentials/cookies are read.

[PERFORMANCE_PHASE5.md](PERFORMANCE_PHASE5.md) reports uncapped Phase 4 comparisons and limitations. A 30 FPS cap is a target, not proof the target iMac sustains it. Reduced resolution is useful if pixel/shader work dominates; it cannot eliminate all CPU/native-skeleton or host scheduling stalls.

## Local acceptance and export

1. Launch fresh and after an upgrade. Check automatic local time, all four manual slots, both rain modes, clear restoration, crossfade lighting, portrait/wide resizing and persisted assignments. Select the old sunset alternative, restart, then restore supplied sunset. Temporarily remove a custom file and confirm the current valid image remains.
2. Test all 15 standing previews, replacement blends, listening/talking, standing rest/wake and maximum intensity from multiple angles. After careful ground calibration, inspect each short sequence from the front/sides; verify foot contacts, return home and image-specific calibration. Unsupported seat/floor transitions cannot be tested.
3. Compare Low/native and Low/0.75 outside the editor. Use F3 over several minutes, then low-power 15 FPS. Test optional adaptive reduction, weather Off/On, minimized/restored rendering, focus and resize. Record iMac frame times, CPU/GPU use and thermals; cloud software rendering cannot predict these.
4. With your existing authenticated ChatGPT tab, test manual start/end and output capture, listening/thinking indicators when detectable, lip sync only from tab output, permission failure, bridge/browser restart and duplicate-start protection. Start Voice during calibrated steps: check landing/hold/resume, no unintended call interruption, and delayed scenery restoration. See [Mac setup](SETUP_MAC.md).

The checked-in macOS universal export preset includes raw optimized backgrounds as **Keep File** resources. A PCK export and isolated pack asset/scene-load check verify packaging; no matching macOS binary export, signing/notarization or target-iMac run was performed. To build a local Mac app, install matching 4.6.3 templates, use Project → Export → macOS, and review local signing/Gatekeeper requirements. The Python bridge stays external; use the existing pairing-file picker or `AISORA_BRIDGE_CONFIG` for an exported viewer.

[TEST_RESULTS.md](TEST_RESULTS.md) lists cloud evidence. Native authenticated ChatGPT Voice, real audio/capture permissions/playback, Mac dialogs/hotkeys/focus delivery, audible ambience, exported Mac binary and sustained iMac performance still require local testing.

[Sunset preview](images/phase5-sunset.png) · [Night preview](images/phase5-night.png). The supplied illustration has no verified ground at the default anchor, so these stationary composition previews do not establish walkability.
