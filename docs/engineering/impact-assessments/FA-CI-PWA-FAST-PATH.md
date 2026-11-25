# Impact Assessment & Design — Pipeline CI/CD Focado em PWA + Builds Nativos Sob Demanda

- **Task ID:** `FA-CI-PWA-FAST-PATH`
- **Branch:** `chore/ci-pwa-fast-path`
- **Base:** `master` (`7ae6789`)
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/github-pr-guardian/SKILL.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`

---

## 1. Problem Statement & Observed Bottlenecks

Em `master` (`7ae6789`), cada `pull_request` e cada `push` em `master` executa dois workflows sobrepostos (`ci.yml` e `validation.yml`):
1. `ci.yml` já executa testes SQL PGlite, consistência de versão, formatação (`dart format`), `dart analyze`, suíte completa `flutter test --coverage` com trava `>=90%` em criptografia/guards, teste E2E headless em Linux (`xvfb`), compilação Web + Android APK (no mesmo job serial `build_android_and_web`), Windows, Linux, macOS e iOS IPA (`macos-latest`).
2. `validation.yml` duplica no mesmo PR/push os testes SQL PGlite, `dart analyze`, subconjunto `maps`, suíte completa `flutter test` (`all`), compilação Windows e compilação iOS (`macos-latest`).
3. No fluxo atual do projeto, o desenvolvimento diário é validado via **PWA (Web)**, enquanto pacotes nativos completos (Android APK, iOS IPA, Windows, Linux, macOS) só são necessários em releases (`v*`) ou sob demanda explícita. A fila do runner `macos-latest` e a junção de Web + Gradle Android no mesmo job aumentaram o tempo e a variabilidade dos checks sem ganho para iterações Web.

---

## 2. Design & Safety Rules

1. **Separar `build_web` de `build_android` em `.github/workflows/ci.yml`:**
   - `build_web` (`Build Web (Release)`) e `integration_test_headless` passam a depender apenas de `[ version_consistency, sql_safety ]`, executando em paralelo a `test_and_lint` (`Flutter Analyze, Format & Test`).
   - `deploy_web_pages` (`Deploy Web to GitHub Pages`) passa a usar `needs: [ test_and_lint, integration_test_headless, build_web ]` com `if: github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/v')`. Isso garante que o Web em produção continua **100% bloqueado** se qualquer teste unitário, estático, cobertura ou E2E falhar, ao mesmo tempo em que reduz o tempo pós-merge até o deploy Web pela metade.
2. **Gating de builds nativos pesados (`build_android`, `ios_build_check`, `build_windows`, `build_linux`, `build_macos`):**
   - Permanecem com `needs: [ test_and_lint ]` e recebem `if: startsWith(github.ref, 'refs/tags/v') || (github.event_name == 'workflow_dispatch' && inputs.build_native_platforms == true)`.
   - Adicionado input booleano `build_native_platforms` (padrão `false`) em `workflow_dispatch` para acionar todas as plataformas sob demanda no GitHub Actions.
   - `publish_release` passa a referenciar `[ integration_test_headless, build_web, build_android, ios_build_check, build_windows, build_linux, build_macos, verify_release_configuration, build_sai_release_map ]` e baixa tanto `release-dist` (APK) quanto `web-release-archive` (`web-release.zip`), preservando 100% dos artefatos de release e checksums em tags `v*`.
3. **Eliminar duplicação em `.github/workflows/validation.yml` + alinhar Ruleset `Protect master` (`27731399`):**
   - `validation.yml` passa a disparar apenas via `workflow_dispatch` (validação independente multiplataforma sob demanda, sem duplicar PRs/pushes na `master`).
   - Sem `paths-ignore` em nível raiz (atendendo `github-pr-guardian/SKILL.md`).
   - Atualizar o ruleset `Protect master` no GitHub para substituir `Flutter tests (all)` pelos checks não-duplicados do pipeline ativo (`Flutter Analyze, Format & Test`, `Build Web (Release)`, `Headless Integration Tests (Linux xvfb)`, `SQL Isolation, RLS & E2EE CAS (PGlite)`, `Secret Pattern Audit & SBOM Generation`, `Lint GitHub Actions Workflows`).
4. **Atualização documental em `.agents/skills/github-pr-guardian/SKILL.md`:**
   - Alinhar os exemplos de checks obrigatórios citados na linha de governança com os jobs reais do pipeline Web-first.

---

## 3. Affected Files & Rollback

- `.github/workflows/ci.yml`
- `.github/workflows/validation.yml`
- `.agents/skills/github-pr-guardian/SKILL.md`
- `docs/engineering/impact-assessments/FA-CI-PWA-FAST-PATH.md`
- **Zero alterações em `lib/`, `test/`, SQL/Drift, `ENABLE_E2EE_SYNC`, segredos ou comportamento do aplicativo.**
- **Rollback:** reverter o commit na `master` e restaurar `Flutter tests (all)` no ruleset `Protect master` caso deseje voltar ao modelo anterior.
