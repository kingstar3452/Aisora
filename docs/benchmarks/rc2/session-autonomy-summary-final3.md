# Complete performance matrix

Milliseconds except FPS, CPU and memory. Each value is the median of all 3 valid run statistics; P95 range is min–max across repetitions. CPU covers the measured case (one logical core = 100%). RSS is Linux process memory, not physical GPU usage. Paced cases include deliberate frame waits. All raw runs and frame traces are retained separately. 0 instrumentation-invalid samples remain in the audit data and are replaced explicitly; no slow valid run is trimmed.

| Case | Build | Mean | Median | P95 | P99 | FPS | CPU % | Peak RSS MiB | P95 range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cursor-idle-low | r2 | 27.46 | 26.97 | 40.32 | 58.01 | 36.41 | 195.77 | 411.88 | 37.91–75.89 |
| cursor-speaking-low | r2 | 27.02 | 25.91 | 35.57 | 44.62 | 37.01 | 200.69 | 559.09 | 34.47–43.94 |
| cursor-listening-low | r2 | 27.33 | 26.61 | 38.18 | 54.02 | 36.59 | 200.82 | 565.43 | 34.74–38.76 |
| cursor-idle-low | rc1 | 28.97 | 27.11 | 39.52 | 63.03 | 34.52 | 201.80 | 417.14 | 31.04–48.45 |
| cursor-speaking-low | rc1 | 30.13 | 28.08 | 47.73 | 60.09 | 33.19 | 198.31 | 562.80 | 32.84–103.01 |
| cursor-listening-low | rc1 | 25.36 | 25.19 | 31.99 | 44.88 | 39.44 | 203.57 | 567.23 | 29.48–45.26 |
| cursor-idle-low | rc2 | 28.98 | 28.39 | 37.40 | 55.27 | 34.51 | 201.88 | 422.32 | 35.33–40.34 |
| cursor-speaking-low | rc2 | 33.21 | 27.81 | 48.72 | 59.76 | 30.12 | 195.53 | 564.23 | 41.36–50.51 |
| cursor-listening-low | rc2 | 26.66 | 25.55 | 34.94 | 49.66 | 37.51 | 199.65 | 568.78 | 30.95–136.03 |
