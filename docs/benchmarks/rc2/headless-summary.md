# Explicit-source headless profiles

Linux CPU-only probes, three repetitions per build. Values are medians of per-run statistics. No native render flush, HTTP or real audio: these are script costs, not complete-app frame times or iMac FPS. Stage instrumentation itself has overhead. Sources and runtime SHA-256 match the final rendering matrix; all 18 raw probe records are in [the lossless archive](canonical-headless-profiles.json.gz).

## Character tick including stage instrumentation

| State | Working r2 ms/tick | Updater rc1 ms/tick | Candidate rc2 ms/tick |
| --- | --- | --- | --- |
| idle | 0.08901 | 0.12521 | 0.08687 |
| talking | 0.13308 | 0.17635 | 0.12887 |
| walking | 0.16225 | 0.16769 | 0.14371 |
| seated | 0.21995 | 0.27193 | 0.20968 |
| sleeping | 0.29661 | 0.33471 | 0.21538 |

## App plus character tick, including default autonomy when present

| Scenario | Build | Mean ms | Median ms | P95 ms | P99 ms |
| --- | --- | --- | --- | --- | --- |
| idle | r2 | 0.11193 | 0.08300 | 0.21900 | 0.54200 |
| idle | rc1 | 0.11254 | 0.09000 | 0.21300 | 0.52500 |
| idle | rc2 | 0.12761 | 0.09800 | 0.23500 | 0.59200 |
| cursor | r2 | 0.13156 | 0.08500 | 0.21200 | 0.63800 |
| cursor | rc1 | 0.14030 | 0.09500 | 0.30700 | 0.69100 |
| cursor | rc2 | 0.12367 | 0.10200 | 0.22800 | 0.41500 |
| speaking | r2 | 0.15949 | 0.12300 | 0.31900 | 0.64900 |
| speaking | rc1 | 0.15503 | 0.11800 | 0.30300 | 0.59600 |
| speaking | rc2 | 0.16498 | 0.13200 | 0.33900 | 0.68900 |

The earlier launcher incorrectly reused an old source path. Its superseded microsecond claims are withdrawn; this explicit-path run replaces them. Do not attribute all differences to the cache: shared-host variation and the requested new autonomy work remain.
