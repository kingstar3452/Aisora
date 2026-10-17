# Phase 3 performance evidence

On the available Linux software renderer, the median per-run **mean wall frame interval fell from 82.34 ms to 47.47 ms** in the controlled talking scene (42% lower); the median per-run p95 fell from 101.19 to 62.46 ms. These are uncapped measurements, with the same engine, resolution and animated source asset. The frame cap is disabled for measurement. Low also submits 38% fewer draw calls and 29% fewer primitives than Phase 2's default.

This improves measured render cost but **does not establish steady 30 FPS** in cloud or on the 2017 iMac. Low still misses a 33.3 ms budget on this software renderer, and shared-host stalls remain. Intel Mac GPU/driver behavior, sustained thermals and a release export are untested. Use the F3 overlay and [local checklist](PHASE3.md#inspect-performance-locally) on your actual machine.

## Controlled results

17 October 2026 UTC / 18 October Singapore. Before: Phase 2 commit `9e83e0a79b7c46d36d18f4c8321de76181a2969f`, its default lightweight setting (original MToon, no MSAA). After: this PR's Phase 3 implementation. Normal application default remains 30 FPS; tests below bypass that cap.

Each cell is the **median of three per-run statistics**, not a pooled frame percentile. Ranges show the minimum/maximum per-run mean. Raw per-run records: [talking](benchmarks/phase3-talking.json). All scenes have the whole park and actual character, with seeded talking gestures and varying synthetic mouth amplitude; UI/network processing are disabled.

| Configuration | Mean frame ms | Mean range ms | p95 frame ms | Draw calls | Submitted primitives |
| --- | ---: | ---: | ---: | ---: | ---: |
| Phase 2 default | 82.34 | 72.18–97.87 | 101.19 | 47 | 82,139 |
| Phase 3 Low | 47.47 | 44.89–69.95 | 62.46 | 29 | 58,022 |
| Phase 3 Balanced | 56.28 | 48.42–79.76 | 76.15 | 29 | 58,560 |
| Phase 3 High | 296.29 | 262.34–336.07 | 398.19 | 38 | 73,907 |

A second, separate **Idle** comparison (three runs, 60 warmup + 120 measured frames) keeps natural motion/gestures/blinking active with no synthetic mouth input. Median per-run mean fell from **79.99 to 43.89 ms**, and median per-run p95 from **105.53 to 53.19 ms**. See the [idle records](benchmarks/phase3-idle.json).

High restores the original per-light MToon/outline materials and enables 2× MSAA; it is an optional visual tradeoff, **not recommended on this software renderer**. Balanced adds canopy/grass detail to the efficient material path. Wide run ranges overlap, so small preset timing differences should not be treated as precise hardware rankings. Cloud figures cannot predict your iMac's FPS.

The headless character-script microbenchmark (40 batches of 100 ticks after 300 warmup ticks) measured median per-run mean **0.0506 → 0.0428 ms/tick** for Phase 2 → Low. Its median batch p95 was **0.0636 → 0.0753 ms/tick**: the tail did not consistently improve on this shared CPU. This is script/setter work without a per-tick native render flush; it excludes deferred skeleton/skin/blendshape rendering cost. It neither proves CPU-only animation was the original bottleneck nor measures total CPU/GPU frame time. Render work remains the much larger observed cost.

Reported video memory rises from **246.0 to 248.9 MiB** in Low/Balanced (High 257.7 MiB). New baked textures/geometry add about 2.9 MiB; original resources remain available for High. Godot's tracked static allocation is approximately 37.1 → 37.2 MiB. These engine monitors are not total process RSS or physical GPU residency. Memory reduction is not claimed.

## What removes work

- Nine park passes are removed by merging trunks/twigs and furniture and sharing one cutout foliage batch; Low/Balanced also omit nine character outline passes. Original textures/skeleton/VRM bytes are retained.
- Efficient character shading uses one albedo sample and a soft vertex-normal shade, without imported multi-texture/per-light MToon work. High restores original material objects. Materials are cached across switches.
- Joint rest axes/limits and four owned expression bindings are cached. Layer dictionaries are reused. Unchanged bone/face values skip native writes, including exact zero mouth closure. Native buffers are no longer dirtied by resetting all imported expressions each frame.
- Hair and eye bones update at 8/12 Hz, or 4 Hz inactive. Primary breathing, posture, gestures, head movement, blinking and amplitude lip sync continue every rendered frame.
- Petals are opaque instanced vertex animation with static transforms/seeds. There is no CPU particle step or per-frame transform allocation/upload. Static park meshes are built once; textures/vertex colors supply grass detail and soft shading.
- Existing 30/15/10/5 FPS policies lower inactive work while keeping HTTP/Voice processing enabled. They are separate from the uncapped performance improvements above. F3 uses a fixed 120-value ring and formats/sorts only twice a second while visible.

## Reproduce

Environment: Godot 4.6.3 official Compatibility, Linux 6.18.55 x86_64, Intel Xeon Platinum 8573C (five visible vCPUs, four-core CPU quota), 32 GiB container memory. Xvfb/Mesa 25.0.7 llvmpipe LLVM 19.1.7, `LP_NUM_THREADS=2`, Dummy audio. This is software OpenGL on a shared host. The virtual driver warns that VSync switching is unsupported. No benchmark engines run concurrently.

The same `tools/benchmark.gd` runs against an imported archive of Phase 2 and the current project. Render runs use **960×600**, 60 warmup + **180 measured frames**, Engine.max_fps=0 and a requested disabled VSync. Fixed 1/30-second animation steps and seeded motion make pose workload comparable. Wall intervals include engine, deferred native rendering, window-system and scheduler waits; they are not GPU timer queries. Imports, UI, network and startup are excluded from the sampled window. A single process-time monitor value in each raw record is informational, not an aggregate CPU measurement.

```sh
# Uses an archive, leaving the development checkout and existing preferences intact.
aisora_baseline="$(mktemp -d /tmp/aisora-phase2.XXXXXX)"
git archive 9e83e0a79b7c46d36d18f4c8321de76181a2969f | tar -x -C "$aisora_baseline"
"$aisora_baseline/tools/run_godot.sh" --headless --editor --import
# Requires a display; run on Mac directly, or set DISPLAY for Linux Xvfb.
python3 tools/compare_performance.py --baseline "$aisora_baseline" --runs 3 --frames 180
# Lower-cost comparison of just the default preset:
python3 tools/compare_performance.py --baseline "$aisora_baseline" --presets low
# One current-scene sample:
./tools/run_godot.sh --audio-driver Dummy --script res://tools/benchmark.gd -- --mode=render --quality=0 --frames=180
```

Set `LP_NUM_THREADS=2` for the exact llvmpipe cloud configuration; this variable has no effect on native Mac OpenGL. Set `GODOT_BIN` if needed. Results/logs go to ignored `.local/`; compare repeated runs at the same resolution after imports with other workloads closed. Use `--state idle` for the idle workload and `--output` to retain a separate report. Benchmarking requires Python only as a developer tool; it introduces no runtime dependency.
