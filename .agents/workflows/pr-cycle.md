---
description: Ciclo completo de desenvolvimento, validação automatizada e abertura de Pull Request no field-assistant.
---

# Workflow: /pr-cycle

Este workflow descreve o ciclo de 5 passos obrigatórios que deve ser seguido rigorosamente para qualquer alteração, correção ou nova funcionalidade antes de abrir um Pull Request.

---

### Passo 1 — Leitura de Governança e Mapeamento de Arquivos
1. Ler com atenção as regras mandatórias em `AGENTS.md` e as regras de sessão em `.agents/rules/field-assistant-ci-gate.md`.
2. Consultar as skills relevantes em `.agents/skills/` (ex.: `map-engine-architect`, `ios-offline-first-qa`, `flutter-pre-pr-gate`).
3. Listar explicitamente quais arquivos serão modificados antes de aplicar qualquer edição.

### Passo 2 — Implementação Mínima e Testes Unitários
1. Implementar apenas as mudanças necessárias para cumprir a demanda, mantendo o diff enxuto e focado.
2. Escrever ou atualizar testes unitários cobrindo o caminho feliz e cenários de borda.
3. Garantir ausência de imports diretos de `dart:io` ou `package:sqlite3/sqlite3.dart` em código alcançável pela Web (usar *conditional imports*).
4. Fechar adequadamente conexões SQLite (`db.close()` / `db.dispose()`), sinks e subscrições.

### Passo 3 — Execução do Gate Pré-Push
1. Executar a ferramenta de validação pré-push:
   ```powershell
   .\tool\pre_push.ps1
   ```
2. Garantir que a checagem de formatação (`dart format`) e análise estática (`flutter analyze`) passem com exit code 0.

### Passo 4 — Testes Automatizados e Checagem de Plataforma
1. Executar a suíte de testes unitários relevante ao módulo alterado:
   ```powershell
   flutter test test/<modulo_ou_arquivo_test.dart>
   ```
2. Caso a alteração toque código executado na Web, validar que os scripts e bundles atendam aos padrões de compatibilidade e segurança (ex.: `node --check scripts/<script>.js`).
3. Garantir que todos os testes passem com exit code 0.

### Passo 5 — Commit Semântico e Abertura do Pull Request
1. Criar commits semânticos seguindo a especificação Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `refactor:`, `docs:`).
2. Fazer push da branch de trabalho para o remote:
   ```powershell
   git push -u origin <nome-da-branch>
   ```
3. Abrir o Pull Request utilizando o template preenchido de `.github/pull_request_template.md`:
   ```powershell
   gh pr create --base master --head <nome-da-branch> --title "..." --body "..."
   ```
