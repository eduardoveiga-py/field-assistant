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
## Regras Obrigatórias de CI, Multiplataforma e Qualidade
1. **Formatação antes do push:** Sempre rode `dart format lib test integration_test` antes do push para evitar falhas na checagem de formatação do CI.
2. **Conditional imports para Web:** Use *conditional imports* para `dart:io` e `sqlite3` em arquivos alcançáveis pela Web.
3. **Feature flag E2EE:** Mantenha `ENABLE_E2EE_SYNC` com `defaultValue: false` no código.
4. **Fechamento de SQLite no Windows CI:** Sempre feche conexões SQLite em `stop()`/`dispose()` para evitar bloqueios de arquivo no CI Windows.

### Verificação pré-push
Antes de realizar o push, execute o script `tool/pre_push.ps1` (`.\tool\pre_push.ps1`), que executa `dart format --output=none --set-exit-if-changed lib test integration_test` e `flutter analyze`, falhando imediatamente caso algum passo retorne erro.

### Plano gradual de lints
Novas regras de lint em `analysis_options.yaml` devem ser habilitadas de forma gradual e segura (iniciando com `cancel_subscriptions: true` e `close_sinks: true`), evoluindo a qualidade do código sem introduzir regressões em massa.
