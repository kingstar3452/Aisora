# Phase 2: expressive Aisora in the sakura park

Historical Phase 2 notes. For the current presets, render paths and park implementation, see [Phase 3](PHASE3.md).

Continue using `dev/aisora-companion` / the updated pull request. Pull that branch in your existing checkout, reopen `project.godot` with **Godot 4.6.3**, let scripts import and run the project. No new packages, assets, APIs or extension reinstall are required. The original VRM bytes, browser controller protocol, local pairing file and existing camera/audio/shortcut preferences remain compatible.

## Try the changes

- Aisora now stands on a path in a procedural Japanese garden with pink sakura canopies, grass, a bench, a stone garden lantern and falling petals. The camera stays centered; camera/light controls remain available.
- Leave Idle (1) running: continuous breathing, swaying, gaze and small hair motion combine with occasional distinct moments. Open Settings (Tab), choose Wave / Stretch / Look around / Adjust posture and click **Preview idle gesture** to see one immediately. This chooses manual Idle; **0** returns to automatic Voice-linked states.
- Listening (2) leans forward with a head tilt and focused gaze. Talking (4) adds expressions, head emphasis and occasional hand gestures; only actual output amplitude opens the mouth. Thinking (3) remains a manual presentation test.
- Sleeping (5) takes 2.4 seconds to settle into a standing rest pose with closed eyes, lowered head and relaxed arms. Waking takes 1.8 seconds plus a gentle recovery. The bench is decorative; no untested seated/cloth animation is assumed.
- Settings → **Animation intensity** adjusts body/gaze/hair/gesture motion (0–1.6, default 1.00), leaving blinking and lip sync independent. The existing synthetic mouth test remains explicitly labeled.

## Performance and window behavior

The default is a **normal, opaque, resizable application window**, initially 1120×700, minimum 800×500. F11/window controls still offer optional full-screen. Window focus/minimize handling changes rendering cost; it does not navigate ChatGPT, send end-Voice commands or stop the bridge.

| Situation | Frame cap / effect |
| --- | --- |
| Foreground default | 30 FPS target |
| Optional Low-power mode | At most 15 FPS, disables MSAA, six moving hair roots, at most 12 falling petals and fewer grass tufts |
| Another app has focus | At most 10 FPS; decorative petal updates suspended |
| Minimized | At most 5 FPS; decorative petal updates suspended |
| Settled sleeping | At most 10 FPS and six falling petals; rest/wake transitions use the active cap |
| Restore focus | Restores the configured foreground/low-power limit |

The FPS slider permits 15–60; **30 or 15 is recommended for the 2017 iMac**. Background policy always picks the lower applicable cap. “Graphics” chooses lightweight/no MSAA or standard/2× MSAA; low-power overrides MSAA without losing the saved graphics preference. “Petal density” ranges from off to 56 maximum; the default is 25, with lower low-power/sleep caps. Its update work is bounded and stops while hidden/inactive, with no catch-up burst on resume.

Trees and blossom clusters are static. Three shared opaque blossom MultiMeshes cover eight trees; trunks/branches use two batches and the bench uses two. Grass, distant hills, fallen blossoms and falling petals are also batched. Petals are low-poly opaque meshes rather than transparent particle clouds. Lighting uses two simple directional lights and ambient color. No real-time shadow maps, bloom, SSAO, GI, physics objects or large downloads are introduced. The ground contact oval is a static opaque mesh.

Godot's HTTP requests now use supported worker threads: network progress no longer requires multiple render frames per connection. This fixes the observed timeouts with the original client at a 5 FPS cap. Requests/status callbacks still return through Godot's frame loop; the browser owns the actual ongoing Voice session. Throttling never stops the Python bridge or that browser session. Empty/failed responses are handled without parsing invalid JSON or logging misleading engine errors.

## Local Mac acceptance still required

The cloud validates the actual VRM poses, environment creation, preference persistence, rendering limits and real Godot/HTTP integration with a **simulated** browser/audio source. It also renders and inspects Idle, Wave, Stretch, Listening, Talking, Sleeping, Waking and Settings using software OpenGL.

It cannot certify native consumer ChatGPT Voice, tab capture permissions/playback, real macOS focus/minimize delivery, Samsung display/full-screen behavior, global F8 or sustained performance on the 2017 Intel iMac. Use the local checklist in [SETUP_MAC.md](SETUP_MAC.md). During a real Voice call, minimize Aisora and switch apps for a minute, then restore and verify fresh status/lip sync and audible Voice continuity. In Activity Monitor, compare 30 FPS with Low-power 15 FPS and reduce resolution/petals if needed. No thermal protections are changed.
