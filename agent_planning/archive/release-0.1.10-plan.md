# 0.1.10 release: Intel test-exit hang, then beta, production and install

Authorized by the user on 2026-09-15: fix the Intel CI hang in a small PR, get CI green on `main`, publish `v0.1.10-beta1`, then production `v0.1.10`, and install it on this Mac. The fallback (`continue-on-error`) needs explicit approval first.

## State at planning time

- PR #55 merged to `main` as `ec49834`. Version 0.1.10, build 12.
- On `main`, required checks pass (build/test/lint on macOS 26, CodeQL, secret scan, dependency review), but the CI workflow fails because the new `intel-test` job times out.
- `Scripts/release.sh` requires `CI` and `CodeQL` to both succeed on the release commit, so the release is blocked.

### Symptom on `macos-15-intel` (Xcode 26.3, Swift Testing 1501)

- All 66 tests pass in under a second, then the `swift test` process never exits and the 15-minute step timeout fires.
- Reproduced three times: with `--parallel`, without it, and with `--disable-xctest`.
- The first Intel run did exit, but it had one failing test.

### Diagnostic

Run `34981707782` on throwaway branch `claude/intel-test-exit-hang` executes each test target separately under a 180 s bound. For any command that doesn't exit, it prints the process table.

## Hypotheses, in order of evidence needed

1. **A test leaves a process or thread that blocks exit.** Candidates:
   - Fake app-server grandchildren (`sleep`, `yes`) orphaned when `CodexStatusService.stop` kills only the direct child.
   - A dedicated status-read `Thread` still blocked in `Process.waitUntilExit()`.
   - The cancelled fifth read in the cancellation test.

   **Evidence:** the hang follows one target or test when targets run separately, and the process table shows a leftover child of the test runner.
2. **Swift Testing or SwiftPM on this image does not exit after a passing run** (toolchain or runtime issue, independent of our tests).

   **Evidence:** even the pure-validation filter (`ProfileValidationTests`, no processes, no threads) hangs.
3. **The OpenProfileManager test target** (links the AppKit executable) keeps an AppKit/run-loop resource alive.

   **Evidence:** only the `OpenProfileManagerTests` filter hangs.

## Steps

1. **Read the diagnostic.** For each target, record exit code or HANG, plus the process table.

   **Done when:** each hypothesis above is marked supported or ruled out, with log lines as evidence.
2. **Narrow if needed.** If a whole target hangs, bisect it with `--filter` on individual suites or tests in one more bounded run.

   **Done when:** the smallest hanging filter is known, or bisection shows hanging is independent of which tests run (hypothesis 2).
3. **Fix the root cause in a small PR.**
   - **If hypothesis 1:** make the code or test release the resource. For example, terminate the whole fake app-server process group, or ensure `readStatus` never leaves a blocked waiter. Add a regression test that fails before and passes after on the macOS 26 job where possible; otherwise the Intel job itself must pass.
   - **If hypothesis 3:** isolate the app-model tests from AppKit state, or run that target in its own bounded step.

   **Done when:** the Intel job passes unchanged apart from the fix, including packaging and launching the x86_64 app, and every other check stays green.
4. **Fallback, only with user approval.** If hypothesis 2 holds or no fix is found within two diagnostic rounds:
   - Wrap the Intel test command in a bounded runner that fails on any test failure and on missing test-run output, and treats only a post-completion exit hang as non-fatal.
   - Or set `continue-on-error: true` on the `intel-test` job.
   - In both cases, document exactly what the job still proves in `docs/RELEASING.md`, the changelog, and the PR.

   **Done when:** the user approves the exact wording and mechanism.
5. **Delete the diagnostic branch** after its evidence is recorded in the fix PR.
6. **Merge the fix PR** after CI (including Intel) and CodeQL pass. Then confirm `CI` and `CodeQL` succeed on the resulting `main` commit.
7. **Pre-release checks on this Mac.**
   - Free disk space of at least 8 GiB.
   - Clean tree: move the untracked plan file aside.
   - No agent-session variables in the release environment.
   - Stale `.scratch` artifacts parked outside the checkout.
   - Gitleaks and TruffleHog pre-scan both clean.
8. **Beta:** `Scripts/release.sh --beta 1` with the stable Xcode, the Developer ID identity and Node 24.

   **Done when:** `v0.1.10-beta1` is an immutable prerelease with all four asset attestations verified, and 0.1.9 is still the latest release.
9. **Production:** `Scripts/release.sh`.

   **Done when:** `v0.1.10` is immutable, latest, notarized, and all four attestations are verified.
10. **Install on this Mac from the published ZIP.**
    - Verify the checksum and attestation, extract with ditto, and check codesign, stapler, Gatekeeper and both architectures.
    - Replace the installed copies atomically and run the packaged smoke test on the installed app.

    **Done when:** app and CLI report 0.1.10 build 12 and the smoke test passes.
11. **Closeout PR.**
    - Update the changelog date and open 0.1.11, plus `README`, `PROJECT_STATUS`, `MEMORY`, the daily memory file, the `SECURITY_AUDIT` release section and the archived plan.
    - Restore `.scratch`.

    **Done when:** it is merged with CI green and local `main` is clean.
