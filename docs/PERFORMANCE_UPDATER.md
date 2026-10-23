# Updater and facial clarity — measured evidence

The candidate preserves all Phase 6 body actions, IK/contact corrections, transitions and personality gestures. No animation was removed or reduced to achieve a benchmark. Facial clarity/Voice responsiveness take priority over decorative effects. **These Linux results do not certify consistent 30 FPS on the iMac.** Native Ventura and authenticated ChatGPT Voice remain untested.

## Changes

- The updater performs no per-frame work while disabled/idle. Native download/network/hash/copy operations run in a separate process, with 1 Hz status polling only during a task. Launch checks default off and defer during Voice. Staging cancels if a known Voice session begins. No continuous update daemon is installed.
- Existing body/gesture/breath/blink updates and amplitude envelope remain continuous. Eye movement now stays at the full animation rate; the existing lower-rate hair sampling remains. No rig, animation asset, mouth sensitivity, audio gate or browser protocol was replaced.
- The actual Face mesh keeps its full available LOD; Low/Balanced retain the original eye/eyebrow/mouth textures and morphs with a gentle face-only energy floor/reduced tint/shading. This increases visible facial detail instead of reducing animation quality. Original High MToon materials remain available. Face clarity can be disabled explicitly.
- During conversation, optional resolution protection temporarily raises an existing reduced 3D setting to at least 90% (up to 1920 pixels) without overwriting the saved manual resolution. Native resolution remains the default. A visible unfocused conversation keeps the selected facial cadence; minimized rendering and the explicit 15 FPS mode remain throttled. The separate Voice bridge continues unchanged.
- Sustained-load adaptation now reduces petals/secondary weather/branches **before** lowering character resolution. Character resolution is not automatically lowered during protected conversations. Conversation decoration is reduced to half budget while user density/settings stay saved unchanged. Adaptive quality remains opt-in; no oscillating upgrades, background image warping or new expensive post-processing is added.
- Foreground petals fade out around the projected face region so they do not pass over the mouth. This uses two small uniforms updated at 10 Hz, not CPU particle simulation. Rain/fog already render behind the 3D character. Baked objects in illustrations are never animated individually.

Manual camera height/distance and character placement controls are retained. The original hair/VRM mesh is not remodeled; extreme poses or user camera settings still need local visual acceptance. No geometry/lighting adjustment is claimed to solve all possible hair/clothing occlusion.

## Before/after method

Baseline: unmodified repair commit **bf2aee817f26da62a03187f9363580f57f71aeec**, imported in an isolated archive. Candidate: updater/facial changes on the same development branch. Godot **4.6.3 Compatibility**, Linux cloud, Xvfb, Mesa llvmpipe software OpenGL, `LP_NUM_THREADS=2`, Dummy audio, Low/native, 960×600. Both run the same current benchmark harness, fixed sunset/RNG and 1/30 simulation ticks, **uncapped** frames, UI and real network disabled. The application coordinator is exercised with idle or **simulated** bridge Voice/audio state; the native updater is inactive.

Each case has three sequential interleaved repetitions, 60 warmup + 180 measured frames. Summary values are medians of per-run statistics, not pooled percentiles. CPU is whole-process user+system time divided by wall time, including startup/warmup (one logical core = 100%). Process RSS is sampled at 10 Hz from Linux procfs; it is not GPU memory. Shared cloud/software-driver variation is substantial. All runs are retained: [idle raw records](benchmarks/updater-idle.json), [simulated speaking records](benchmarks/updater-talking.json).

| Case | Mean frame ms | P95 frame ms | Approx FPS from mean | Whole-process CPU % | Sampled peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline idle | 37.59 | 57.11 | 26.6 | 79.4 | 489.1 |
| Candidate idle | 36.24 | 65.73 | 27.6 | 80.0 | 465.0 |
| Baseline simulated speaking | 50.57 | 92.87 | 19.8 | 87.1 | 509.8 |
| Candidate simulated speaking | 44.62 | 76.04 | 22.4 | 84.0 | 474.3 |

Idle mean improves slightly here, but **idle P95 worsens and CPU is essentially unchanged**. Simulated-speaking mean/P95 and sampled memory improve in this sample; this does not establish a hardware-independent speedup or stable pacing. Both P95s exceed the 33.3 ms budget; consistent 30 FPS was **not achieved in this software-rendered comparison**. There is no claim of native iMac performance improvement or real Voice latency validation.

The facial detail change increases Low submissions from approximately **23,850 to 29,138 primitives**, while draw calls stay **22**. Simulated conversation's lower petal budget removes a few primitives. This is a deliberate small facial-detail tradeoff; it is not presented as lower geometry cost. Existing body animation/contact correctness remains covered by the actual-VRM one-hour simulated session and render suite.

Reproduce:

```sh
DISPLAY=:99 LP_NUM_THREADS=2 python3 tools/compare_performance.py \
  --baseline /path/to/imported-bf2aee8 --baseline-label phase6-r2 \
  --current-label updater --runs 3 --frames 180 --presets low \
  --modes render --state idle --coordinator \
  --output .local/updater-idle.json
# Repeat with --state talking and a distinct output file.
```

Omit DISPLAY/LP_NUM_THREADS on a normal Mac display. CPU tick microbenchmarks remain separately available; these wall-frame results include deferred renderer/skeleton work. Sampled RSS currently requires Linux procfs; use Activity Monitor for native Mac memory/CPU.

## Acceptance on the target Mac

Compare the retained working app and updater candidate at identical window size, Low/native, sunset, weather and density for 10–15 minutes each. Record F3 mean/P95 plus Activity Monitor CPU/memory, idle and with **real authenticated ChatGPT Voice/tab capture**. Exercise walking, seat/floor rest, waking, all personality gestures, silent listening, speech/mouth visibility, unfocused/minimized recovery, and background-first adaptation. Repeat the same scene with editor Run Project and standalone; no native editor/standalone comparison or Intel thermal result is claimed here. Do not replace the working app until local acceptance passes.
