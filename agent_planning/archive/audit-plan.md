# Codebase audit and implementation plan

## Goal and first principles

A local profile launcher needs explicit selection, private storage, bounded read-only status, and thin CLI/native adapters. It does not need account automation, a generic workflow framework, duplicate APIs, unused design systems, or installation on every test run. Preserve the official authentication boundary and existing behavior. Work locally on the existing branch; no commit, push, release, global configuration edit, or new worktree.

## Audit coverage

- Core and CLI: every Swift source and ProfileCore test; registry/storage security, launch/signature validation, subprocess protocol, batch concurrency, and argument parsing.
- Native app: every Swift view/model/localization source and native tests; Apple bundled concurrency and SwiftUI guidance.
- Tooling: every shell/Swift script, hooks, CI workflows, structural rules and rule tests.
- Website/video: HTML/CSS/JS, Remotion source and configs; binary assets treated as outputs, not code. Dependency manifests/pins reviewed without upgrading packages.
- Agent docs: AGENTS.md, CLAUDE.md, project status/memory, contributing and architecture/performance/security guidance; current official Fable 5.1 and GPT-6 Astra prompting guidance.

## Accepted work, in order

1. Establish baseline with Scripts/check.sh and capture exact failures/tool versions. Preserve useful regression tests; no deletion quota.
2. Delete unused core entry points: LaunchPlanner.loginPlan/logoutPlan, unused path-based ACL overload, ProfileManager.appPlan/status, and CLI manager wrapper. Narrow internal-only access when callers prove it. Keep descriptor-based ACL validation and all storage/output bounds. Verify existing core suite and PTY launch integration.
3. Delete obsolete website selectors and unused reveal/copy-command paths. Prove selectors have no current consumers, then compare all computed styles for current DOM at 1440x1000 and 390x844, inspect before/after screenshots, and run site validation. Record actual CSS/JS byte deltas; do not equate bytes with measured LCP.
4. Delete unused video duration exports and permanently disabled audio/theme/prop branches only after caller checks. Run video type/lint checks and preserve frame behavior.
5. Consolidate native success/failure types into the existing generic outcome, reuse its error conversion, and remove the forwarding path wrapper. Preserve background execution of blocking filesystem/process work. Verify Swift suite and packaged real-window smoke.
6. Improve verification DX: stop npm ci from reinstalling dependencies on every check; install pinned video dependencies in bootstrap and CI before checks. Check prerequisites early. Always package current debug source before launch. Document isolated-home QA, focused/full gate selection, LLDB access, and one writer/build tree per authorized checkout. Add no worktree manager or production debug backdoor.
7. Replace duplicated agent prose with a concise canonical AGENTS.md and CLAUDE import. Keep product/security invariants, task scope, concrete acceptance checks, model guidance links, and brief continuity/ownership guidance. Runtime model settings stay in the harness, not product source.
8. Run focused proof then full gate, inspect rendered surfaces, and run autoreview at P3 on the frozen final diff. Verify findings before fixing. Update changelog and repository memory with measured results and remaining limits. Archive this plan on completion.

## Deliberately retained / deferred

- Descriptor-relative I/O, writer lock, private modes, firmlink resolution, output/record caps and strict scalar parsing: regression-backed security boundaries, not slop.
- Thin ProfileManager boundary, SwiftUI subviews, single pinned argument-parser dependency: meaningful ownership/compiler boundaries.
- Collector JSON rescans and O(n²) comparisons at <=128 profiles: bounded; no cache/algorithm rewrite without comparative proof.
- Status cancellation, streaming partial results and larger concurrency: behavior changes requiring a separate defined requirement and realistic fixture evidence.
- Signed release/notarization pipelines and their behavioral test doubles: protect distribution, not redundant test scaffolding.
- Remote timing below the browser/platform floor, automatic worktrees, extra agent frameworks: no speculative optimization/automation.

## Evidence and completion

Record baseline/final commands, exit status, byte counts, render comparisons and material blockers below. A green build does not establish live authentication compatibility or macOS minimum-version behavior. Do not read real credentials or claim those checks ran. No measurable performance gain is required to justify a confirmed dead-code deletion.

## Findings and disposition

| Area | Evidence | Decision |
| --- | --- | --- |
| Core/CLI dead APIs | No repository callers for login/logout plans, manager app/status helpers or URL ACL overload; both adapters build after removal | Removed; retain the actual descriptor ACL guard and domain façade |
| Native error plumbing | Three identical outcome enums, duplicated error conversion, forwarding path function | Reuse one generic outcome and direct core path validation; preserve task isolation |
| Website | Old selectors absent from sole HTML page; reveal and inline copy-command attributes have zero consumers | Remove only unmatched paths; retain live cascade, clipboard and video handlers |
| Video | Duration exports unused; music source always null; muted never supplied; accent unused | Delete options and branches; sampled PNG equality verifies unchanged frames |
| Verification latency | Old web gate runs npm ci each time, even with unchanged lockfile | Setup installs once; gate checks existing tools and still runs audit/lint |
| Debug freshness | launch.sh tests only whether bundle exists | Always invoke incremental debug packaging |
| PTY proof gap | Old gate accepted a child that prints expected markers then exits 7 | Add wait/exit-status assertions and a deliberate expected-exit-7 case; mutant now fails |
| Dependency audit | Baseline npm audit failed on fast-uri 3.1.5; installed module accepted malformed IPv6 | Added narrow dependency exception to original no-upgrade plan: override/lock 3.1.6 only; positive/negative parse checks and audit pass |
| Tests | Existing filesystem, parser, PTY, distribution and structural-rule tests cover distinct failures | No test deletion justified |

The dependency exception is supported by the upstream [IPv6 advisory](https://github.com/advisories/GHSA-f65p-4m7j-42xc) and [IDN advisory](https://github.com/advisories/GHSA-5jgf-p345-68v8). This proves the dependency defect and remediation, not exploitability of the native application.

## Performance candidates not implemented

1. **Status JSON rescans:** collector repeatedly decodes retained records under its condition lock. Before changing it, compare the ordinary three-response case with a 256-record noisy fixture, preserving duplicate-ID semantics, combined stdout/stderr caps, EOF and timeout behavior. The subprocess probably dominates ordinary latency; no current end-to-end evidence supports a cache.
2. **Cancellation:** a cancelled batch still refills its four-child group. There is no current GUI cancellation action. Define that behavior before adding lifecycle machinery; any future change must prove a >4-profile cap/refill fixture and child cleanup.
3. **Termination timing test:** the <90ms mtime assertion can reflect scheduler noise. It passed here; no flaky failure was reproduced. Prefer a deterministic child-exit handshake if it fails under load, with timing retained in an explicit benchmark.
4. **Packaging path queries:** repeated --show-bin-path calls could be cached within one build, but there is no packaging measurement justifying another table/helper.
5. **UI subdivision and registry validation:** retained. Separate SwiftUI views form useful invalidation boundaries; path comparisons are bounded at 128 profiles and filesystem identity must be revalidated.

## Verification evidence

- Baseline Swift checks passed 59 tests. The default Node 26.7 shell failed the explicit Node24 gate; all web proof uses installed Node24.20/npm11. Baseline web audit then exposed the existing fast-uri issue, preserved in `/tmp/opm-web-before.log`.
- Core deletion proof: 57 core tests passed. Native localization contributes the other two tests.
- Website: 190 elements × main/before/after styles × eight desktop/mobile states exactly equal. Four full-page screenshots inspected. CSS 18,051→13,734 bytes; JS 1,807→1,133 bytes. Local clipboard/video spies verify handlers, not OS clipboard or decoded playback. Raw evidence: `.scratch/slop-web-proof/results.json` and adjacent snapshots.
- Remotion: exact PNG matches at Launch frame 330, Tutorial frame 65 and GuiTutorial frame 820; these are samples, not full movie/audio equivalence. Video lint/typecheck passed.
- Web verification A/B: three alternating runs on the same patched dependency tree, Node24.20, all exit0. Before 5.561/5.377/5.247s; after 2.160/1.999/1.968s. Median 5.377→1.999s (~63% lower). One-minute host load 5.72–6.23; full load averages and logs in `.scratch/verification/web-check-timing.json`. This is local warm-check latency, not app startup or page LCP.
- PTY positive control: original test with forced child exit7 incorrectly passed; updated test with the same mutation fails exit1. Normal run includes zero and nonzero child-exit expectations and passes.
- Dependency proof: valid IPv6 remains accepted; malformed IPv6 is rejected after patch; npm audit reports zero vulnerabilities.
- Packaged debug app: signing verification, bundled version, PTY and process-to-visible-window smoke passed (single sample 282.479ms; no launch-speed improvement claimed).
- Real native CUA pass under a synthetic isolated home: empty state; add; selected profile; edit; invalid relative path disables save; valid rename persists; duplicate ID displays error without dismissing editor; removal confirmation and cancel preserve profile. Quit the synthetic instance. Real account login, actual desktop launch and Finder installation were not exercised.

## Closeout

The full gate passed with Node24.20/npm11. Bootstrap also passed through its documented entry point. That real setup run exposed one more unnecessary operation: blanket chmod made the sourced release_artifacts.sh library executable. Removed the chmod (Git already tracks script modes), restored the library mode, and reran bootstrap plus shellcheck; no mode drift remains.

A fresh-context verifier independently checked the diff, style snapshots, sampled PNGs, PTY mutant and timing artifacts and found no actionable regression. Autoreview at P3 also returned scoped-clean; final rerun covers the bootstrap correction. No remote CI, publication, real authentication, minimum-macOS compatibility, whole-video/audio equivalence or launch/LCP speedup is claimed. Changes remain local and uncommitted on main.

## Release continuation

The user subsequently authorized version bump, commits, push, beta and production deployment. Target: numeric app version 0.1.7/build 9, beta tag v0.1.7-beta1, production tag v0.1.7. This macOS project distributes through GitHub Releases; GitHub Pages deploys main and there is no TestFlight or separate web staging target. A small release-wrapper option classifies verified beta publications as prereleases without replacing latest stable.

The release scan initially flagged Remotion Studio's bundled Algolia search key in generated before/after comparison bundles. Those untracked generated bundles were moved to the external Codex artifact directory; screenshots, raw style snapshots and frame PNGs remain in the ignored proof directory. No scan exception or credential value was added to source. The source release retains strict secret scanning.
