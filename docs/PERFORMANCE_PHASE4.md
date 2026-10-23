# Phase 4 performance evidence

Phase 4 replaces the default procedural scenery with a native canvas illustration behind the original 3D character. The optional Phase 3 park is constructed only when selected. The comparison below uses **uncapped rendering**, so any measured reduction is separate from the normal 30 / 15 FPS policies.

The controlled talking comparison reduced the median per-run mean interval **49.15 → 25.57 ms** (48% lower), with median per-run p95 **78.11 → 36.21 ms**. The latter still exceeds the 33.3 ms budget for 30 FPS. Idle mean is **43.84 → 21.55 ms** (51% lower) with p95 **56.87 → 26.87 ms**. The application retains its normal 30 FPS target; the benchmark does not cap away slow frames.

| Workload / version | Mean frame ms | Per-run mean range ms | p95 frame ms | Draw calls | Submitted primitives |
| --- | ---: | ---: | ---: | ---: | ---: |
| Talking · Phase 3 Low | 49.15 | 48.96–50.71 | 78.11 | 29 | 58,022 |
| Talking · Phase 4 Low hybrid | 25.57 | 22.64–29.15 | 36.21 | 24 | 39,794 |
| Idle · Phase 3 Low | 43.84 | 43.19–45.48 | 56.87 | 29 | 58,022 |
| Idle · Phase 4 Low hybrid | 21.55 | 20.73–23.48 | 26.87 | 24 | 39,794 |

Values are **medians of three per-run statistics**, not pooled frame percentiles. Raw records: [talking](benchmarks/phase4-talking.json), [idle](benchmarks/phase4-idle.json). Ranges show shared-host variability; they are not confidence intervals. These new Phase 3 samples are the comparison baseline; older Phase 3-vs-Phase 2 numbers were collected at a different time.

The headless talking character microbenchmark is essentially unchanged: median mean **0.04207 → 0.04156 ms/tick**, median batch p95 **0.06922 → 0.05302 ms/tick**. The new actions preserve the earlier efficient animation path; small shared-CPU timing differences are not evidence of a material speedup. Idle mean is also essentially unchanged at **0.04173 → 0.04198 ms/tick**, with median batch p95 **0.06827 → 0.05259 ms/tick**. Native rendering remains the much larger measured cost.

Reported talking video memory **increases 248.9 → 251.8 MiB**, and tracked static allocation **37.2 → 41.4 MiB**. Additional illustration/UI resources outweigh omitted park resources in these monitors. These are engine accounting values, not total process RSS or physical GPU residency. No overall memory reduction is claimed. Selecting the fallback later also retains its built resources until app exit.

These are Linux **software OpenGL** measurements on a shared host, not a 2017 iMac result. Slow frames remain; no sustained 30 FPS or thermal claim is made for either platform. The benchmark uses the original bundled illustration because the user-selected first picture was not exposed as a downloadable cloud file. Its decoding, final visual placement and performance need checking locally through the image picker.

## What removes work

- Native `Environment.BG_CANVAS` composes the background and existing 3D world in one viewport. There is no second full-size render target or duplicate character render. This also preserves the existing VRM lighting, morphs and quality materials.
- The hybrid default omits all procedural park geometry. The fallback still works and builds once when selected, instead of paying its construction and texture cost at hybrid startup. After switching back, it remains resident but hidden and its animation stops.
- The background is one texture sample per pixel. Its small ambient variation is calculated at vertices and reuses that draw; no extra full-window tint, blur, bloom, depth effect or displacement pass is used. Optional parallax is a rigid offset, at most 10 Hz.
- A maximum of 40 simple petal quads (24 Low, 32 Balanced, 12 low-power) shares one instanced mesh. Static seeds/transforms drive vertex animation without per-frame CPU particle or transform uploads. Two separate corner branches use lightweight vertex sway.
- Background, foreground and overlay images have bounded dimensions before decoding. GPU background long-edge budgets are 1280 / 1600 / 1920; foreground is at most 512. The initial bundled SVG raster is 1280×800. No large picture is downloaded at runtime.
- Existing quaternion/face caches, reused animation layers, reduced-frequency hair/eye motion and unchanged-write skipping remain. New hand targets are authored values on the actual skeleton; no per-frame IK search is introduced. Inactive finger offsets skip rest-axis work. Weighted selection runs at action boundaries, with at most a 1 Hz retry for all-zero weights.
- Inactive/minimized shader clocks and parallax pause. The existing 10 / 5 FPS render caps and background secondary-motion reduction remain; threaded HTTP and browser Voice are independent. Normal foreground targets 30 FPS, low-power 15 FPS, settled standing rest 10 FPS.

Quality presets and F3 diagnostics are retained. Low/Balanced use the earlier efficient character materials; High restores original MToon/outlines and 2× MSAA. High is an optional visual tradeoff and is not recommended for the software renderer. Functional hybrid checks cover all three presets; timing comparisons here deliberately use matching **Low** settings. There is no claim that all quality presets or arbitrary window sizes meet the target.

## Reproduce the controlled comparison

Before: Phase 3 commit `091c4e96365b82452b37893a62ec3301aa25ae77`, Low. After: this Phase 4 implementation, Low illustrated default. The **same** `tools/benchmark.gd` runs in both projects against the same original VRM, seeded poses and fixed 1/30-second animation steps. Talking uses varying synthetic mouth amplitude; Idle uses zero mouth amplitude with natural motion/gestures/blinking. Short Idle render windows primarily sample continuous micro motion, not every long scheduled action; the separate headless tick workload spans much more animation time. UI and bridge processing are disabled, with isolated nonexistent preference paths; no user images or pairing data are loaded.

Each workload uses three interleaved before/after repetitions, one engine at a time, at **960×600**, 60 warmup + **180 measured frames**, `Engine.max_fps=0` and a requested disabled VSync. Averages/percentiles include deferred native rendering, window-system and scheduler waits; they are wall intervals, not GPU timer queries. Startup/import time is excluded. Reported p95 is the median of per-run p95 values, not a pooled percentile.

The separate headless character microbenchmark uses 40 batches of 100 ticks after 300 warmup ticks. It measures script/setter work without a native render flush per tick. It excludes deferred skeleton, skin and blendshape rendering, so its small timing must not be presented as total animation CPU/GPU cost.

Environment: Godot 4.6.3 official Compatibility, Linux 6.18.55 x86_64, Xeon Platinum 8573C (five visible CPUs, four-core quota), 32 GiB container memory, Xvfb/Mesa 25.0.7 llvmpipe LLVM 19.1.7, `LP_NUM_THREADS=2`, Dummy audio. The virtual driver warns that VSync switching is unsupported. No other tests/renderers ran concurrently with the comparisons.

```sh
aisora_baseline="$(mktemp -d /tmp/aisora-phase3.XXXXXX)"
git archive 091c4e96365b82452b37893a62ec3301aa25ae77 | tar -x -C "$aisora_baseline"
"$aisora_baseline/tools/run_godot.sh" --headless --editor --import
# Requires a display. Run directly on Mac, or set DISPLAY for Linux Xvfb.
python3 tools/compare_performance.py --baseline "$aisora_baseline" \
  --baseline-label phase3 --current-label phase4 --presets low \
  --runs 3 --frames 180 --output .local/phase4-talking.json
python3 tools/compare_performance.py --baseline "$aisora_baseline" \
  --baseline-label phase3 --current-label phase4 --presets low \
  --runs 3 --frames 180 --state idle --output .local/phase4-idle.json
```

Set `GODOT_BIN` if needed. `LP_NUM_THREADS=2` reproduces the llvmpipe setup and has no effect on native Mac OpenGL. Logs and results default to ignored `.local/`. For an iMac comparison, close other workloads, keep the resolution/quality and browser/call conditions constant, and take several sustained samples using F3. Check native window minimize/restore and a real Voice session separately; the cloud HTTP fixture simulates those states and audio, not the native macOS events or ChatGPT service. See [the Phase 4 local checklist](PHASE4.md#test-locally-and-remaining-limits).
