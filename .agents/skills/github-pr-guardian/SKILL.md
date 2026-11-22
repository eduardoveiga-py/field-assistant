---
name: github-pr-guardian
description: Enforces pre-branch conflict checks, GitHub Actions YAML hygiene, CodeQL SHA alignment, anti-regression coding standards, and local verification gates before opening or updating pull requests.
---

# GitHub PR Guardian & Anti-Regression Skill

Use this skill before creating any branch, editing `.github/**`, modifying shared interfaces/network/sync/auth flows, or opening a Pull Request against `master`.

## 1. Pre-Branch Conflict Check (Parallel PRs)
Before creating a new branch or starting implementation, inspect all open PRs and the files they touch to avoid merge conflicts and duplicated work:

```bash
gh pr list --state open --json number,title,headRefName,files
```

- If an open PR already modifies the same files or module, coordinate, rebase, or wait before branching from `master`.

## 2. GitHub Actions & YAML Hygiene (`.github/**`)
- **YAML Syntax Validation:** Always validate YAML syntax for every modified or created file under `.github/**/*.yml` before committing/pushing.
- **No Root `paths-ignore` on Required Checks:** Never use a root-level `paths-ignore` in workflows that produce **Required** status checks on `master`, because skipped workflows leave required checks in a permanently pending state and block merges.
- **CodeQL Action SHA Alignment:** Whenever updating or pinning `github/codeql-action`, keep the commit SHA strictly aligned between `github/codeql-action/init` and `github/codeql-action/analyze` (and any other `github/codeql-action/*` steps in the workflow).

## 3. Anti-Regression & Test Standards
- **Update `Fake*` / `Mock*` Classes:** Whenever an interface, abstract class, or service signature is altered, immediately update all corresponding `Fake*` and `Mock*` implementations across `test/` and `integration_test/`.
- **No Silent `catch` in Network / Sync / Auth:** Never swallow exceptions with an empty or silent `catch` block in network, synchronization (`sync`), or authentication (`auth`) flows. Always log, rethrow, or surface structured error state so failures are observable and recoverable.
- **Loopback Test Server Error Handling:** In test suites using local loopback HTTP/socket servers (`HttpServer.bind(InternetAddress.loopbackIPv4, 0)`), always handle `SocketException` and attach `onError` handlers so transient socket/connection resets do not crash the test runner.

## 4. Local Verification Gate
Before pushing or opening a PR, run focused module tests locally followed by the repository pre-push script:

```powershell
flutter test test/<modulo>/
.\tool\pre_push.ps1
```

## 5. Deployment / Release Reminder
- **Always remind the user:** Changes merged or committed on feature branches do **not** go live automatically—updates only enter the **IPA (iOS)** and **Web** artifacts **after merging into `master` and running the corresponding build**.
