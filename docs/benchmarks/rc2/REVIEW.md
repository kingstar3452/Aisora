# RC2 review measurements

The tables on this page are from Linux Xvfb / Mesa llvmpipe, not an iMac or physical GPU. All valid slow runs and frame traces are retained. The additional completed [native Intel Mac comparison](native-summary.md) uses Apple Software Renderer and is kept separate. No authenticated ChatGPT Voice latency is measured. Read the [release decision and unresolved regressions](../../PERFORMANCE_RC2.md) before interpreting selected rows.

The retained scene harness advances the original subsystems explicitly with the app process disabled; new autonomy work and complete unmodified exported applications have separate measurements below. Harness FPS is not complete standalone FPS. The main matrix contains 59 scenarios × three builds × three repetitions = 531 measured cases. Values are medians of per-run statistics; percentiles are not pooled. All runs use 60 rendered warmup frames and 180 measured frames, except the declared 1,800-frame memory cases. Animation keeps the original 1/30 s workload; explicitly paced cases use real frame delta. Complete per-run CPU and sampled RSS, source and harness fingerprints, method flags, desktop-session policy and container-throttling counters are in the compressed raw JSON.

r2 = bf2aee8 (working repair); rc1 = 5ca43c5 (updater/facial baseline); rc2 = 2142475 (accepted runtime, including requested autonomy defaults and corrected head tracking). The three sources use identical original case definitions and the same external harness.

## Low preset character states

| State | Build | Mean ms | Median ms | P95 ms | P99 ms | FPS | CPU % | Peak RSS MiB | P95 repetition range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idle | r2 | 30.71 | 28.25 | 39.80 | 147.40 | 32.56 | 202.44 | 416.20 | 34.47–80.90 |
| idle | rc1 | 41.40 | 37.25 | 55.96 | 77.33 | 24.16 | 195.63 | 420.51 | 48.13–70.84 |
| idle | rc2 | 32.48 | 29.77 | 47.54 | 64.32 | 30.79 | 203.31 | 423.49 | 31.82–49.53 |
| speaking | r2 | 34.11 | 30.57 | 46.49 | 150.80 | 29.32 | 196.73 | 561.11 | 38.38–82.14 |
| speaking | rc1 | 34.14 | 32.13 | 49.79 | 62.73 | 29.29 | 200.31 | 561.78 | 46.99–51.07 |
| speaking | rc2 | 32.94 | 32.05 | 39.27 | 56.16 | 30.36 | 200.65 | 565.12 | 38.62–47.13 |
| listening | r2 | 34.20 | 28.82 | 60.41 | 96.23 | 29.24 | 187.58 | 565.18 | 47.52–75.87 |
| listening | rc1 | 40.78 | 35.88 | 56.49 | 151.60 | 24.52 | 197.49 | 566.33 | 45.83–69.08 |
| listening | rc2 | 32.11 | 31.53 | 41.95 | 67.37 | 31.14 | 198.93 | 568.83 | 36.73–48.22 |
| walking | r2 | 38.76 | 36.81 | 62.07 | 113.13 | 25.80 | 198.27 | 569.25 | 49.45–75.72 |
| walking | rc1 | 38.71 | 35.72 | 59.05 | 100.04 | 25.83 | 194.77 | 569.89 | 57.98–65.53 |
| walking | rc2 | 31.24 | 28.06 | 42.35 | 53.13 | 32.01 | 202.08 | 573.44 | 33.84–48.03 |
| sitting | r2 | 34.48 | 30.78 | 51.76 | 90.42 | 29.00 | 195.77 | 570.64 | 31.35–65.11 |
| sitting | rc1 | 34.97 | 33.23 | 50.84 | 88.74 | 28.60 | 194.54 | 570.47 | 45.72–104.65 |
| sitting | rc2 | 29.40 | 27.38 | 36.17 | 40.87 | 34.02 | 198.03 | 573.91 | 34.82–53.62 |
| reclining | r2 | 32.97 | 28.47 | 48.58 | 61.76 | 30.33 | 194.08 | 570.65 | 33.27–58.02 |
| reclining | rc1 | 49.54 | 44.93 | 83.71 | 126.81 | 20.19 | 176.73 | 578.34 | 81.70–110.08 |
| reclining | rc2 | 34.64 | 32.08 | 50.80 | 143.76 | 28.87 | 199.32 | 576.07 | 50.73–63.12 |
| sleeping | r2 | 34.35 | 32.45 | 52.05 | 100.53 | 29.11 | 192.91 | 574.95 | 31.57–97.54 |
| sleeping | rc1 | 47.70 | 42.51 | 82.68 | 147.88 | 20.96 | 193.26 | 578.39 | 44.11–125.50 |
| sleeping | rc2 | 31.47 | 30.26 | 42.52 | 59.41 | 31.78 | 200.33 | 578.57 | 35.69–53.94 |
| personality | r2 | 37.26 | 33.13 | 56.03 | 70.92 | 26.84 | 191.24 | 573.99 | 43.25–291.40 |
| personality | rc1 | 58.21 | 46.14 | 130.28 | 260.29 | 17.18 | 177.97 | 581.28 | 48.27–1168.13 |
| personality | rc2 | 29.75 | 27.65 | 44.50 | 62.08 | 33.62 | 198.58 | 576.33 | 34.66–44.79 |

## Complete coverage

[All 177 scenario/build summaries](session-summary-final3.md) · [CSV](session-summary-final3.csv) · [JSON](session-summary-final3.json). These include every preset, scenery/weather, gesture, resolution, connection, crossfade, native/reduced viewport, inactivity, pacing and memory scenario. Higher-quality and paced cases are reported individually; they are not mixed into an overall FPS score.

[Cursor/hover input comparison](session-autonomy-summary-final3.md) uses an additional identical three-case input workload on all builds. These 27 cases are separate from the original matrix. New default behavior is enabled on rc2; older builds have no mouse-awareness feature.

## Actual Linux exported players — 30 FPS target

| State | Build | Runs | Mean ms | Median ms | P95 ms | P99 ms | FPS | CPU % | Peak RSS MiB | P95 range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idle | r2 | 3 | 33.58 | 33.07 | 41.32 | 65.24 | 29.78 | 156.35 | 418.79 | 40.88–43.18 |
| speaking | r2 | 3 | 33.38 | 33.22 | 40.46 | 59.16 | 29.96 | 156.74 | 414.45 | 39.18–43.21 |
| idle | rc1 | 3 | 34.57 | 33.38 | 47.07 | 74.60 | 28.92 | 164.66 | 424.41 | 39.13–102.60 |
| speaking | rc1 | 3 | 33.55 | 33.12 | 41.25 | 51.64 | 29.81 | 167.92 | 418.72 | 39.53–50.83 |
| idle | rc2 | 3 | 33.33 | 33.23 | 40.53 | 50.53 | 30.00 | 163.08 | 420.05 | 39.90–43.40 |
| speaking | rc2 | 3 | 33.72 | 33.06 | 40.56 | 80.83 | 29.66 | 178.26 | 422.00 | 39.22–232.30 |

[All raw runs including startup/warmup traces where collected](session-native-final3.json.gz).

## Extended actual Linux exported idle — 1,800 measured frames

| State | Build | Runs | Mean ms | Median ms | P95 ms | P99 ms | FPS | CPU % | Peak RSS MiB | P95 range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idle | r2 | 3 | 37.81 | 33.86 | 59.66 | 101.20 | 26.45 | 171.57 | 420.31 | 43.08–62.61 |
| idle | rc1 | 3 | 35.31 | 33.11 | 47.77 | 95.80 | 28.32 | 174.25 | 424.60 | 42.64–48.22 |
| idle | rc2 | 3 | 34.82 | 33.17 | 45.65 | 83.41 | 28.72 | 173.42 | 425.89 | 45.09–55.55 |

[All raw runs including startup/warmup traces where collected](session-native-extended-final3.json.gz).

## Godot project player versus Linux exported player

| State | Build | Runs | Mean ms | Median ms | P95 ms | P99 ms | FPS | CPU % | Peak RSS MiB | P95 range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idle | project-player | 3 | 37.10 | 34.55 | 57.21 | 122.70 | 26.95 | 182.95 | 414.78 | 55.81–186.60 |
| speaking | project-player | 3 | 33.97 | 33.30 | 44.77 | 76.25 | 29.44 | 179.65 | 419.00 | 44.55–59.93 |
| idle | linux-release | 3 | 34.60 | 33.33 | 49.12 | 66.41 | 28.90 | 176.79 | 425.48 | 43.77–53.31 |
| speaking | linux-release | 3 | 33.35 | 33.34 | 40.76 | 53.21 | 29.98 | 171.98 | 420.18 | 40.21–61.35 |

[All raw runs including startup/warmup traces where collected](session-project-player-final3.json.gz).

The project player uses the Godot tool binary without editor UI. This is **not an editor-versus-standalone UI benchmark**.

## Historical workload rerun — hidden UI, no real HTTP, sunset

| State | Build | Runs | Mean ms | Median ms | P95 ms | P99 ms | FPS | CPU % | Peak RSS MiB | P95 range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| idle | r2 | 3 | 28.41 | 26.24 | 41.42 | 56.08 | 35.20 | 167.86 | 494.64 | 31.29–69.13 |
| talking | r2 | 3 | 25.40 | 24.84 | 38.02 | 43.84 | 39.37 | 175.63 | 466.63 | 30.49–39.37 |
| idle | rc1 | 3 | 26.94 | 26.32 | 32.67 | 39.11 | 37.13 | 175.90 | 465.57 | 30.62–41.42 |
| talking | rc1 | 3 | 29.20 | 27.18 | 43.05 | 55.47 | 34.25 | 177.71 | 482.03 | 38.72–46.46 |
| idle | rc2 | 3 | 35.89 | 31.40 | 56.96 | 110.67 | 27.86 | 177.01 | 510.87 | 41.04–60.43 |
| talking | rc2 | 3 | 32.08 | 29.26 | 47.14 | 97.64 | 31.18 | 170.88 | 516.08 | 41.87–76.66 |

[All raw runs including startup/warmup traces where collected](session-legacy-final3.json.gz).

Legacy CPU/RSS include startup and warmup; they are not the measured-frame-only process statistics in the newer matrix/player probes.
The original requested 57.1/65.7 ms idle P95 and 50.6/44.6 ms speaking means belong to an earlier shared-host session. This matched three-build rerun retains that original hidden-UI/no-HTTP workload but uses the explicit persistent test desktop for all builds. It cannot establish that an environment change is an application speedup.

## Interpretation limits

Physical GPU utilization, VRAM pressure, power and thermals are unavailable. Software renderer CPU use is not Intel iMac GPU use. Three repetitions and their ranges expose substantial shared-host variation; they do not establish statistical significance. Settings, full animation cadence, shaders, textures, facial quality and workload are preserved. No trimming or fastest-run selection is applied. Successful functional tests and small script-stage savings do not prove stable 30 FPS or universal frame-time improvement.

Native Ventura/iMac and authenticated Voice acceptance remain required before recommending replacement of the working installation. Keep publication held pending review of the complete report and explicit approval.

## Additional evidence and reproduction

- [Native Mac: 24 state/build summaries](native-summary.md), [CSV](native-summary.csv), [JSON](native-summary.json), [all 72 records and traces](native-matrix.json.gz), [exact eight-case catalogue](native-cases.json), and [CPU accounting calibration](accounting-calibration.json). Source job: [39846700428](https://github.com/kingstar3452/Aisora/actions/runs/39846700428), macOS 15.7.9 x86_64 / Apple Software Renderer. These are project-player measurements with the same explicit subsystem harness, not native exported-player FPS or a physical GPU test.
- [Canonical headless summary](headless-summary.md), [all 18 probe records](canonical-headless-profiles.json.gz). These replace the withdrawn exploratory microsecond claims after the source-path audit; fingerprints match the rendering matrix.
- [Native packaging/startup/render/signature/atomic-swap record](native-macos-validation.json) and [independent Linux ZIP revalidation](native-zip-verification-linux.json). Gatekeeper rejects the quarantined ad-hoc candidate; normal Finder launch is not established.
- [Final 1,324 core checks plus 13 Go groups/vet](final-core-check.log.gz). Linux fixture-based Voice tests do not exercise authenticated ChatGPT.
- [SHA-256 manifest](SHA256.json) covers every file in this evidence directory except the manifest itself. Raw JSON is losslessly gzip compressed; no scored outliers were removed.

To regenerate a summary, decompress its raw JSON and run `python3 tools/summarize_performance_matrix.py /path/to/raw.json --output /path/to/summary`. For the native subset add `--cases docs/benchmarks/rc2/native-cases.json`; for the input subset use `--cases tools/autonomy_cases.json`. Summary values are medians of the three recorded run statistics, not pooled percentiles.

For fresh Linux rendering runs, use `tools/run_performance_matrix.py` with three separate source archives, `.benchmark-source-commit` markers, the recorded original case catalogue, official Godot 4.6.3 and an isolated persistent Xvfb/D-Bus desktop. Set `LP_NUM_THREADS=2`, do not run competing renderers/builds, preserve the recorded viewport/quality/seed/frame counts, and keep every valid run. Use `tools/measure_player.py` separately for actual exported players. The exact cases/method/fingerprints are embedded in each raw archive. This environment policy can be reproduced but cannot reproduce shared-host scheduling or manufacture iMac measurements. `tools/run_macos_performance.py` retains the historical fixed-source native probe; its CI evidence upload refuses to overwrite existing private assets.
