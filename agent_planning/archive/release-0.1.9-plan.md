# 0.1.9 review fixes and release

Authorized by user 2026-09-15: fix all review findings, security review, code-review + autoreview, bump, changelog/docs, commit, push (PR — main is protected), beta then prod release via Scripts/release.sh, install locally.

## Fixes (done when each has proof)
1. AppModel.reload overlap: latest reload wins; stale results dropped; isRefreshing tracks newest. Proof: red→green @MainActor test with injected status reader.
2. ProfileManager.statuses: blocking readStatus runs on a dedicated Thread per read (max 4) bridged by continuation; a DispatchQueue failed the strict-pool test because pipe callbacks share throttled dispatch workers. Proof: test under LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 red→green.
3. AppModel: @concurrent helpers replace Task.detached; save in-flight guard disables Save.
4. NSApp.activate() replaces activate(ignoringOtherApps:).
5. Menus: Hide/Hide Others/Show All/Services, Bring All to Front, Help menu registered, Refresh ⌘R. Localized en-US/pt-BR.
6. Directory chooser: sheet-modal NSOpenPanel (keep canCreateDirectories=false: panel-created dirs are 0755 and fail privacy validation).
7. Typed FilesystemOperation / PathField enums replace string matching; CLI English text preserved.
8. ProfileDraft struct replaces 4-string closure.
9. Nits: drop .textContentType(.username), redundant a11y labels, sidebar container label; share bounded read loop.

## Gates
swift test; Scripts/check.sh; package + test_packaged_app; security audit; code-review; autoreview P3; PR CI/CodeQL; release --beta 1; release; install.
