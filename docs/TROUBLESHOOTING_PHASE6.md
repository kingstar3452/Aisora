# Phase 6 quick troubleshooting

- **Nothing new moves automatically:** major autonomy and full-body rest default off to preserve Phase 5. Enable them after calibrating clear space for the displayed image. Check action weights and interval, automatic state 0, no Voice/session guard, no pending fade and a focused window.
- **Sit/lie/walk is refused:** end Voice first; confirm the exact image's calibration and sufficient scaled bounds. Seat/floor rest has a separate enable switch. Sitting requires 1×2 m; lying requires 1.8×2.4 m at unit scale. Return to standing before editing floor/scale/anchor or changing the image.
- **Only standing sleep works:** keys 1–5 retain the original presentation states; the Phase 6 selector controls the separate articulated floor-rest controller.
- **A pose clips clothing:** reduce intensity, use the supported seat heights and default reclining camera, and return to standing. The original skirt/tail have rig-specific corrections, not full cloth collision. Do not assume a replacement VRM supports the same poses. Report the exact action, intensity, angle and stage.
- **A background change waits:** this is deliberate while walking/resting on calibrated space. Feet land or the character gets up before the picture/calibration changes.
- **Cannot select another tab:** end the currently guarded Voice call manually first. If the page no longer reports it, use the popup's clear-stale-guard control only after confirming the call has ended.
- **Browser restart loses selection:** reselect the intended existing Project conversation and click output capture from the popup. Session binding is not carried blindly across browser restarts. The local pairing key and normal ChatGPT login remain intact.
- **No mouth or Listening/Thinking is imprecise:** check fresh browser/capture status and real tab output. Visible activity markers are optional; missing signals are not emotion/microphone detection. Manual ChatGPT Start/End remains the supported fallback when automation is unavailable.
- **Lag persists:** begin with Low/native and F3 diagnostics, then try 15 FPS low-power and fewer/off particles. The cloud Phase 6 comparison has slower frames; no Mac speedup is certified. Compare against the preserved Phase 5 build using [rollback](PHASE6.md#local-acceptance-and-rollback).

[Full setup, supported motions and local acceptance](PHASE6.md) · [Mac browser/audio permissions](SETUP_MAC.md)
