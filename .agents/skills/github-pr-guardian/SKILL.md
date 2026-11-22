---
name: github-pr-guardian
description: Previne conflitos entre Pull Requests, erros de YAML em workflows, falhas de CI multiplataforma (Web/Windows/iOS) e regressões recorrentes antes de criar branches, commits ou PRs no field-assistant.
---

# GitHub PR Guardian & Anti-Regression Standards

Esta skill estabelece diretrizes e validações mandatórias de prevenção de conflitos entre branches/PRs paralelos, higiene estrita de workflows do GitHub Actions, alinhamento de segurança do CodeQL e práticas de codificação anti-regressão no repositório `field-assistant`.

## 1. Checagem pré-branch contra conflitos
Antes de criar qualquer nova branch ou iniciar implementações/edições:
1. Liste todos os Pull Requests abertos e seus arquivos modificados:
   ```bash
   gh pr list --state open --json number,title,headRefName,files
   ```
2. Inspecione se algum PR aberto altera arquivos ou módulos dentro do escopo da nova tarefa.
3. Se houver sobreposição de arquivos:
   - **Pause imediatamente o trabalho.**
   - Avise o usuário para mergear o PR anterior (ou basear a nova branch nele) antes de editar.

## 2. Validação estrita de `.github/**`
Sempre que editar ou criar arquivos em `.github/**` (especialmente workflows ou `dependabot.yml`):
1. **Validação de Sintaxe YAML Local:** Execute a validação antes de qualquer commit ou push:
   ```bash
   python -c "import yaml, glob; [yaml.safe_load(open(f, encoding='utf-8')) for f in glob.glob('.github/**/*.yml', recursive=True)]"
   ```
2. **Proibição de `paths-ignore` no nível raiz:** Nunca adicione `paths-ignore` no nível raiz de workflows cujos jobs sejam `Required` no ruleset `Protect master` (ex.: `Flutter Analyze, Format & Test`, `Windows compilation check`, `iOS compilation check`, etc.). A omissão desses jobs deixa os checks em estado pendente eterno no GitHub, bloqueando o merge na `master`.

## 3. Alinhamento de SHAs do CodeQL
Em `.github/workflows/security-scan.yml`:
- As actions `github/codeql-action/init` e `github/codeql-action/analyze` devem usar **sempre exatamente o mesmo commit SHA/versão**.
- Atualizações de versão do CodeQL devem ser aplicadas em lote e mantidas em sincronia estrita.

## 4. Higiene de interfaces, flags e erros
- **Interfaces e Implementações/Dublês:** Ao adicionar método em interface (`I*`) ou classe abstrata, atualize imediatamente todas as implementações concretas e todos os dublês de teste (`Fake*`/`Mock*`) em `lib/` e `test/`.
- **Proibição de `catch` silencioso:** Nunca usar `catch (_) {}` silencioso em fluxos de autenticação, sincronização ou rede exibidos ao usuário; acumular erros e reportar claramente na UI (ex.: `SnackBar`, diálogos ou banners estruturados com detalhes acionáveis).
- **Servidores loopback de teste:** Em servidores loopback de teste (`ServerSocket`/`Socket` ou `HttpServer`), sempre tratar `onError` e capturar `SocketException` (como Connection reset / `errno 104`) para evitar testes flaky por fechamento abrupto de sockets.
- **Feature Flag E2EE (Defesa em Profundidade):** Manter `ENABLE_E2EE_SYNC` com `defaultValue: false` no código (habilitar apenas via `--dart-define` nos workflows).

## 5. Validação local antes do commit/push
Antes de abrir ou atualizar qualquer PR:
1. Execute os testes do módulo alterado:
   ```powershell
   flutter test test/<modulo>/
   ```
2. Execute a validação pré-push completa:
   ```powershell
   .\tool\pre_push.ps1
   ```

## 6. Pós-abertura do PR
- **Comunicação com o usuário:** Sempre informar claramente ao usuário que as mudanças só entram no IPA/Web após o merge do PR na `master` e conclusão do workflow de build.
- **Auto-merge e status checks:** Confirmar se o auto-merge foi ativado (`gh pr merge <PR> --auto --squash` ou via UI) ou se algum check precisa de ação manual.
## 7. Ferramentas de CI e Release (actionlint, Codecov, Release Please)
- **actionlint:** Validação automática de workflows em `.github/workflows/` a cada PR.
- **Codecov:** Cobertura informativa (`coverage/lcov.info`) em PRs sem bloquear o CI.
- **Release Please:** Uso obrigatório de Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) para geração automática de releases, mantendo consistência de versão com o check `Check Version Consistency` ao revisar PRs de release.
