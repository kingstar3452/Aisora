# Phase 5 performance evidence

Phase 5 reduces submitted character geometry and adds optional 3D-only resolution reduction. It does **not establish sustained 30 FPS on the target iMac**. The uncapped cloud comparison below separates actual rendering work from the normal 30/15 FPS caps. Native resolution remains the default; reduced resolution and automatic reduction are opt-in.

Native Low median means change **21.66 → 21.25 ms idle** and **20.18 → 19.67 ms talking**, about 2% reductions. The ranges overlap substantially; this is not convincing evidence of a general frame-rate speedup. Submitted primitives do fall **39,794 → 23,850** (40%), with **24 → 22 draws**. Reduced 0.75 rendering submits 16,712 primitives with 23 draws, but did **not** improve median frame time here and had a severe talking outlier. It stays optional/off by default.

### Idle

| Version / scale | Mean ms | Mean range ms | p95 ms | p95 range ms | Draw calls | Primitives |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 4 / native | 21.66 | 20.61–23.02 | 32.84 | 25.86–34.99 | 24 | 39,794 |
| Phase 5 / native | 21.25 | 18.11–21.74 | 31.02 | 20.39–36.29 | 22 | 23,850 |
| Phase 5 / 0.75 | 21.68 | 21.58–27.34 | 29.61 | 26.78–54.81 | 23 | 16,712 |

### Talking

| Version / scale | Mean ms | Mean range ms | p95 ms | p95 range ms | Draw calls | Primitives |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 4 / native | 20.18 | 19.94–23.78 | 25.04 | 23.21–37.33 | 24 | 39,794 |
| Phase 5 / native | 19.67 | 19.51–25.20 | 26.66 | 24.01–35.12 | 22 | 23,850 |
| Phase 5 / 0.75 | 21.86 | 20.88–54.83 | 27.75 | 23.90–98.95 | 23 | 16,712 |

All table means/p95 values are medians of three per-run statistics. Ranges include every run, without discarding slow samples. The reduced-resolution talking outlier reaches **54.83 ms mean / 98.95 ms p95**. Native Phase 5 also has runs exceeding the 33.3 ms frame budget. Neither caps nor median statistics prove consistent 30 FPS. Raw records: [Idle](benchmarks/phase5-idle.json), [Talking](benchmarks/phase5-talking.json).

The headless character script/setter path is **slower**, as expected from added pose protection/finger layering: median mean **0.04380 → 0.10209 ms/tick idle** and **0.04027 → 0.08786 ms/tick talking**; median batch p95 **0.05509 → 0.20304 ms** and **0.06493 → 0.13273 ms**, respectively. These small numbers exclude deferred native animation/render work and cannot certify total CPU cost. Geometry submission falls, while script cost rises; no blanket animation-speedup claim is made.

Steady rendered engine accounting is approximately **251.8 → 252.1 MiB video memory** and **41.5 → 43.5 MiB static memory** at native scale. Reduced 0.75 uses about **254.6 MiB video / 43.5 MiB static**, reflecting its extra target. These monitors are not total process RSS or physical GPU residency. Five compressed images on disk do not mean five resident GPU backgrounds. There is no overall memory-reduction claim.


## What changed and what still costs work

- Low/Balanced can use more aggressive native body/hair mesh LOD while retaining original face settings, skinning, textures and morph bindings. Unchanged native bone/face uploads remain skipped. Unchanged nonzero rest-axis pose conversions are now cached too.
- Gesture protection uses cached skeleton data and small body proxies only while gestures are active/settling. It adds measurable script work; it is not a full cloth/collision solver. Analytic leg IK runs only during explicitly enabled short step sequences. Those sequences are off by default.
- The five actual supplied PNGs become 2,727,414 bytes of quality-90 WebP, with no recoloring or invented replacement scenes. Startup loads only the current image. Off-thread clock decoding and two-texture fades avoid loading all five GPU textures. Low's background long edge is 1280; Balanced 1600; High 1920 maximum. An import/preset change or texture upload may still cause a one-off stall; steady-state timing excludes these.
- Rain and petals use capped instanced geometry and vertex animation, without per-frame CPU particle simulation. Clouds/fog are transparent bands, not multiple full-screen blur passes. A crossfade temporarily adds a background draw and one resident background texture. Weather and transitions have functional render coverage; the steady-state comparison is Clear/sunset, not a storm or import benchmark.
- Below native, one transparent SubViewport shares the original 3D world/model, with the main camera's 3D drawing disabled. A 0.75 scale at 960×600 uses 720×450 (56% of native pixels), plus a composite draw. Native background/UI stay sharp. Reduced modes additionally cap the 3D long edge at 1280. Extra target/composition overhead can outweigh pixel savings on some renderers; use F3 on the Mac to choose. The optional adaptive reducer may also be unsuitable on such drivers, so it defaults off.
- Normal presentation no longer formats technical status strings while Settings is collapsed. Diagnostics format at 2 Hz only when enabled. Optional parallax runs at 10 Hz and defaults off. Inactive shader clocks pause; minimized 3D drawing stops. Voice polling stays alive under the existing 10/5 FPS inactive/minimized caps. These policies are not used to manufacture the uncapped comparison.

The larger supplied art, new pose checks and additional optional render target have costs. No overall memory or animation-script speedup is claimed. Original High MToon/outlines and 2× MSAA remain available; all three presets pass functional rendering checks, but High is not timed here or recommended as the iMac starting point. Main recommendations remain Low/native first, then a measured trial of 0.75; 15 FPS low-power is a separate resource-saving option.

## Method and reproduction

Before: Phase 4 commit **`fb8a3f50bde2cad22954aeb948cd3d75ae7aa24d`**, Low, original bundled placeholder illustration. After: this Phase 5 source, Low, actual supplied sunset. Both use the exact same VRM and the **same current `tools/benchmark.gd`**. This is a before/after product comparison, not a single-factor experiment: artwork, branch defaults, shaders and LOD differ. Do not attribute all time changes to one optimization.

Three repetitions interleave Phase 4/native, Phase 5/native and Phase 5/0.75, sequentially with no concurrent tests/renderers. Both Idle and Talking are measured. Rendering uses **960×600**, 60 warmup + **180 measured frames**, fixed seeded 1/30-second character ticks, `Engine.max_fps=0`, requested disabled VSync and Dummy audio. Talking uses synthetic amplitude; Idle uses zero amplitude with continuous natural motion. Short render windows do not exercise every long action. Pose-protection/gait functional tests run separately.

The clock is fixed to sunset **before scene initialization**, avoiding accidental startup clock crossfades. Temporary preferences are isolated and removed. UI, bridge and application coordinator processing are disabled; the harness explicitly advances character/environment and awaits native render completion. Thus it includes deferred skeleton/skinning/morph/render work and window/driver/scheduler stalls, but is not a full app/network/AI latency measurement or a GPU timer query. Startup, import, manual assignment and time-transition stalls are excluded.

The separate headless microbenchmark uses 40 batches of 100 character ticks after 300 warmup ticks. It measures script/native setters **without per-tick native render flush**, so it excludes deferred skeleton/skin/morph rendering. Reduced-scale CPU records are repeat measurements of essentially the same character path, with shared-host variability; they should not be interpreted as an animation optimization.

Environment: Godot 4.6.3 official Compatibility, Linux 6.18.55 x86_64, Xeon Platinum 8573C (five visible CPUs), Xvfb/Mesa 25.0.7 llvmpipe LLVM 19.1.7, `LP_NUM_THREADS=2`. VSync switching is unsupported by this virtual driver. These are standalone **Godot player** processes outside the editor, running source scenes with the standard engine binary. Editor overhead was not separately quantified; no macOS application binary was exported or timed. Shared-host scheduling creates significant run variability.

```sh
aisora_before="$(mktemp -d /tmp/aisora-phase4.XXXXXX)"
git archive fb8a3f50bde2cad22954aeb948cd3d75ae7aa24d | tar -x -C "$aisora_before"
"$aisora_before/tools/run_godot.sh" --headless --editor --import
# Use a display; cloud runs used DISPLAY=:99 LP_NUM_THREADS=2.
python3 tools/compare_performance.py --baseline "$aisora_before" \
  --baseline-label phase4 --current-label phase5 --presets low --scales 1.0 0.75 \
  --runs 3 --frames 180 --state idle --output .local/performance-phase5-idle.json
python3 tools/compare_performance.py --baseline "$aisora_before" \
  --baseline-label phase4 --current-label phase5 --presets low --scales 1.0 0.75 \
  --runs 3 --frames 180 --state talking --output .local/performance-phase5-talking.json
```

The tool preserves raw per-run results and computes medians of per-run statistics, **not pooled percentiles**. Full run ranges must accompany means. Keep other rendering workloads closed and compare the same resolution/preset on the Mac. F3, long sessions, Voice capture, focus/minimize, thermals, actual macOS frame pacing and physical GPU memory remain local acceptance work; cloud values cannot establish the requested iMac target.
