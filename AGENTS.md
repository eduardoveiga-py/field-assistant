# Field Assistant — mandatory engineering rules

For every task in this repository, read and follow:

`.agents/skills/field-assistant-engineering-standard/SKILL.md`

This is mandatory for feature work, bug fixes, refactors, security, sync, database, UI, tests, documentation, and releases.

Non-negotiable:
- Map the complete user journey and dependencies before editing code.
- Write an impact assessment and design before implementation.
- Research authoritative docs and maintained implementations for non-trivial decisions; verify licenses before adapting code.
- Preserve offline-first behavior, user data, account isolation, conflict safety, and feature-toggle history.
- Never claim E2EE, offline support, integration, or test success without end-to-end evidence.
- Do not use a rewrite as the default solution.
- Do not merge, tag, publish, deploy, or declare done unless the skill's quality gate passes: weighted score >=9.7/10, no dimension below 9.0, no unresolved P0/P1, and all applicable hard gates pass.
- Report every changed file, why it changed, exact tests run/results, tests not run, risks, score, branch/commit, and rollback.
- If blocked or below threshold, stop and report NOT APPROVED or BLOCKED. Never fabricate evidence or lower the gate.
