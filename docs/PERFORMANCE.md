# Performance contract

Performance claims in this repository name the surface, metric owner, conditions, and acceptance rule. Static rendering, native launch, user interaction, subprocess status, and offline video production are different workloads; a number from one must not be relabeled as another.

## Static product site

`Scripts/benchmark_site.sh` validates and measures every HTML URL in `sitemap.xml` under these repeatable local conditions:

- one loopback HTTP server and one reused Chromium session;
- fixed desktop `1440x1000` and mobile `390x844` viewports;
- one unrecorded warm-up, then 10 warm-cache navigations per URL and viewport;
- TTFB, FCP, LCP, CLS, and the LCP element retained as raw JSON;
- nearest-rank p50 and p95, with host load and tool versions in the Markdown summary.

The requested static-site gate is strict: p95 FCP and p95 LCP must both be below 50 ms for every sitemap URL in both viewports. Timing is informational unless the caller explicitly supplies `--gate`; equality fails because the contract says “below.”

```bash
Scripts/benchmark_site.sh --samples 10 --gate 50
```

The harness prints and preserves its raw JSON, TSV, browser metadata, server log, and summary in an ignored operating-system temporary directory. For deterministic HTML, local-asset, favicon, manifest, caption-duration, unique-track, and transcript validation without Chromium:

```bash
Scripts/benchmark_site.sh --validate-only
```

Millisecond-scale results are sensitive to the host scheduler and Chromium's frame cadence. A failed 50 ms run remains a failed gate; if repeated warm runs hit a stable tool/platform floor, retain the raw evidence and report that floor rather than weakening or renaming the metric.

The 2026-08-11 release-candidate run could not connect escalated Chromium to the sandboxed loopback server. The low-risk file-URL fallback, under load averages `5.13/5.98/12.73`, recorded desktop p95 FCP/LCP `56/60 ms` and mobile `48/56 ms` after the preferred hero asset fell from 1,511,821 bytes to 9,156 bytes. The strict p95 target therefore remains failed on this host; those fallback numbers are rendering evidence, not a substitute for the blocked loopback contract.

## Native macOS app

- **First window:** measure process launch to the first visible key window in a signed Release build. Record warm and cold launches separately. No 50 ms budget is adopted until the macOS process/window baseline demonstrates that it is meaningful.
- **State change:** measure from the user-input signpost to the first completed frame that reflects the change. Status freshness is a separate subprocess result and must not be included as rendering time.

## CLI and status

CLI/status latency is operational latency, measured with the fixture/profile count, command, cache state, and percentile stated. It is not page load or native rendering.

## Product video

Remotion render time is offline authoring throughput. It has no FCP/LCP or 50 ms page-load gate.
