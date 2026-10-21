# Phase 6 performance evidence

Phase 6 retains the working Phase 5 graphics pipeline and adds opt-in motion. **This cloud comparison shows a rendering regression, not a general speedup.** Keep Low/native as the starting point and measure on the actual iMac. The 30/15 FPS caps are resource policies; they are disabled in the comparison below. No sustained target-Mac frame-rate or thermal result is claimed.

## Phase 5 versus Phase 6

Godot **4.6.3 official / Compatibility**, Linux cloud, Xvfb, Mesa **llvmpipe 25.0.7** software OpenGL, `LP_NUM_THREADS=2`, Dummy audio, 960×600. Baseline is unmodified **`e04341e849834adb480549f17ef57e581e1314e3`**, imported separately. Both versions run the **same current** `tools/benchmark.gd`, Low/native, same original VRM and supplied sunset, fixed RNG and 1/30-second animation ticks, UI/network disabled. Each of three interleaved sequential repetitions measures 180 uncapped frames after 60 warmup frames; no other tests/renderers run concurrently. Source imports precede measurement. Talking uses synthetic amplitude; these are not authenticated Voice or major-action benchmarks.

| State / version | Median mean ms | All run means ms | Median p95 ms | All run p95 ms |
| --- | ---: | --- | ---: | --- |
| Idle / Phase 5 | 21.72 | 21.72, 32.82, 18.93 | 38.38 | 38.38, 52.71, 24.24 |
| Idle / Phase 6 | 28.40 | 23.31, 32.71, 28.40 | 48.51 | 33.28, 63.30, 48.51 |
| Talking / Phase 5 | 27.54 | 21.55, 27.54, 27.88 | 38.26 | 26.55, 38.26, 42.37 |
| Talking / Phase 6 | 37.76 | 30.75, 37.76, 38.62 | 72.44 | 62.11, 72.44, 76.85 |

Statistics are medians of per-run statistics, not pooled frame percentiles. All samples remain, including slow ones. Median means worsen about **31% idle / 37% talking** in this run. Baseline variability and software-driver timing limit attribution, but do not justify dismissing the regression. The talking median exceeds the 33.3 ms budget. These measurements cannot certify consistent 30 FPS or predict Metal/OpenGL driver behavior on the iMac. Raw records: [Idle](benchmarks/phase6-idle.json), [Talking](benchmarks/phase6-talking.json).

Both versions submit **22 draw calls / 23,850 primitives**. Engine video-memory accounting is identical at **252.1 MiB**. Static allocation rises approximately **43.5 → 45.1 MiB**, including new script/controller caches. These monitors are not process RSS or physical GPU residency. No new textures, shaders, scenery geometry or full-screen effect are introduced by Phase 6.

Headless character script/setter microbenchmarks (40 batches of 100 ticks after 300 warmup ticks, no per-tick native render flush) show median means **0.1132 → 0.1233 ms/tick idle** and **0.1037 → 0.1184 ms/tick talking**. Median batch p95 is **0.2130 → 0.2278 ms** and **0.1742 → 0.2012 ms**. Added default script cost is small, but deferred skeleton/renderer work is excluded. It does not explain away the observed wall-frame regression or establish total CPU performance.

## What is bounded and cached

- Major autonomy is off by default. Disabled scheduling does not build a context dictionary each frame. New full-body IK returns immediately when inactive; analytic solvers run only for an active calibrated action.
- Actual rest joint indices/axes, chain lengths, parent transforms and pose arrays are cached once. The IK solver reuses desired-quaternion/transform arrays. Skirt corrections cache their fixed rotations and skip unchanged native position uploads. Walking reuses leg quaternion arrays. During movement the coordinator updates only the contact-shadow anchor, avoiding full background layout and weather-uniform updates every frame. Production does not run the developer CPU-skinned floor probe.
- Existing unchanged native bone/morph setters remain skipped. Personality bindings are discovered once; inactive personality layers perform no extra morph writes. Stage timing is explicitly off by default, so normal frames do not call profiling timers.
- Hair/eye micro-motion retains 8/12 Hz foreground and 4 Hz inactive rates; body transitions and amplitude-driven face remain continuous. Rest owns its long-hair corrective roots rather than fighting secondary animation.
- Existing native mesh LOD, simple Low/Balanced materials, optional reduced transparent shared-world viewport, two-image crossfades, decoded-image budgets, instanced weather and throttled shader clocks are preserved. No new particle simulation, blur, cloth physics, extra model or paid service is introduced.
- F3 retains rolling FPS/mean/p95 diagnostics. Foreground defaults to 30 FPS or 15 low-power; inactive/minimized caps and minimized 3D suppression preserve bridge polling and an active conversation. Full-body transitions complete before the settled-sleep cap applies. These policies are not used in the uncapped comparison.

The newer poses improve expressiveness and bounded contact behavior; they do not establish an overall performance improvement. High retains the original expensive MToon appearance and is functionally checked, not recommended as the iMac default. Native remains the default because Phase 5's reduced-resolution cloud results were mixed. Use F3 and Activity Monitor to decide locally.

## Reproduce and accept on the Mac

```sh
# Import Phase 5 in a separate checkout/archive first; do not reset your working build.
DISPLAY=:99 LP_NUM_THREADS=2 python3 tools/compare_performance.py \
  --baseline /path/to/phase5 --baseline-label phase5 --current-label phase6 \
  --presets low --runs 3 --frames 180 --state idle \
  --output .local/performance-phase6-idle.json
# Repeat with --state talking and a distinct output file.
./tools/run_godot.sh --headless --script res://tools/profile_phase6.gd
```

Omit `DISPLAY=:99 LP_NUM_THREADS=2` for a normal Mac display. CPU microbenchmarks use headless mode; rendering needs a display. The character-only benchmark now hides the illustrated background and its separate foreground, fixing component isolation; this does not change the full-scene comparison.

For native acceptance, compare the editor's Run Project and unsigned Intel standalone app at the same Low/native preset, window size, weather and time override for 10–15 minutes each. Record F3 mean/p95 and Activity Monitor CPU/memory. Exercise walking, sitting, sleeping/waking, all ten personality gestures, Voice and inactive/minimized recovery. Export structure, Linux timings and simulated browser tests do not establish Ventura permissions, capture/playback, real Voice DOM compatibility or Intel GPU/thermal performance.

## Component and active-state diagnostics

A separate **single-run** isolation pass (60 warmup + 90 measured frames, same Low/native hardware and harness) gives character-only mean/p95 **21.41/32.34 ms Phase 5 → 21.36/29.77 ms Phase 6**, with identical **19 draws, 23,810 primitives, 1,350 bone writes and eight face writes** across each sampled run. Background-only is **8.44/11.31 → 24.49/134.73 ms**, with identical **three draws / 40 primitives and zero character writes**. That large background stall occurs with the character hidden and its ticks disabled. This narrows the observed variation beyond the new skeleton controller, but a single diagnostic pass does not prove its cause or overturn the slower full-scene comparison. Raw: [character isolation](benchmarks/phase6-component-character.json), [background isolation](benchmarks/phase6-component-park.json).

Short current-version uncapped active-action runs (60 warmup + 180 measured frames) record mean/p95 **29.77/42.14 ms walking**, **24.00/36.63 ms sitting**, **20.72/30.47 ms sleep entry/recline**. These are individual diagnostic runs, not repeated before/after comparisons. Sitting includes the end of entry and held pose; the longer sleep transition is still entering during the measured window, not a steady fully sleeping benchmark. They exclude coordinator/UI/network and do not certify target-device smoothness. Raw: [walking](benchmarks/phase6-walk_forward.json), [sitting](benchmarks/phase6-sit.json), [sleep entry](benchmarks/phase6-sleep.json).

The opt-in [stage profile](benchmarks/phase6-stage-profile.json) advances the actual original rig headlessly, 330 warmup + 1,800 measured ticks per state. Total ms/tick: idle **0.074**, talking **0.108**, walking **0.130**, seated **0.194**, fully sleeping **0.192**. Gait/rest-IK stage is about **0.052/0.094/0.090 ms** for walking/seated/sleeping. Native setter time, cached body/gesture composition, coarse safety, secondary motion and facial updates are recorded separately in the JSON. Seated breathing/contact corrections still upload about 14 clothing positions per tick; sleeping about eight. These writes are intentional but have deferred native cost that this microbenchmark excludes. Timing overhead is enabled only for this developer probe; no production timers are added to normal frames.

## Exported player versus editor observations

Official 4.6.3 Linux release templates produce a standalone executable/PCK. The matching **Intel x86_64 macOS app ZIP** exports with its PCK, original model/images and engine notices; ZIP CRC, app identifier and thin x86_64 Mach-O header are checked. No Mac executable is run in Linux. Both apps are unsigned/not notarized. Godot's release templates disable arbitrary path overrides; isolated resource-pack checks therefore use the editor executable as a pack player, while actual standalone startup/rendering uses the release executable's own PCK.

Short sequential startup observations use the normal **1120×700** application window and 30 FPS cap, `--print-fps --quit-after 360`. These are one-second CLI summaries, **not per-frame percentiles or uncapped performance tests**. The first unisolated Phase 6 standalone run stalls badly (reported range **1–30 FPS**, median report **11.5**); it is retained. The source player and a player with an idle editor open each report 30 in their short runs. The cause of the initial standalone stall is unresolved.

A follow-up uses separate fresh XDG settings/cache, the same static supplied sunset, Low/native and default weather/particles, no real browser. Both Phase 5 and Phase 6 are exported with the same official release template. Phase 5 release reports **27–31 FPS**, median **28.5**; Phase 6 release **30–30**, median **30**; Phase 6 editor-executable project player **26–31**, median **30**. This does not reproduce the first severe stall. It does not establish a speedup, long-run stability or target-Mac behavior. Running the project with the editor executable and with an idle editor open is covered; embedded editor Game view performance is not measured. Raw reports, including the initial failure: [player observations](benchmarks/phase6-player-observations.json).

Native Mac launch/Gatekeeper, renderer driver behavior, physical microphone/tab capture/playback and authenticated Voice remain untested. Use the preserved Phase 5 source/settings if the replacement fails your local acceptance; the new full-body/autonomy controls remain opt-in.
