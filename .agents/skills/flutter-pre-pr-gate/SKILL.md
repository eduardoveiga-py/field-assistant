---
name: flutter-pre-pr-gate
description: Valida formatação, análise estática, compatibilidade Web/Windows e testes Flutter antes de qualquer commit ou Pull Request no repositório field-assistant.
---

# Skill: Flutter Pre-PR Gate

Esta skill guia o processo obrigatório de verificação de qualidade, análise estática, conformidade multiplataforma e padronização de commits antes de qualquer submissão de Pull Request no repositório `field-assistant`.

## 1. Passo a Passo Obrigatório de Execução

Antes de comitar e enviar branches para o remote, execute em ordem:

1. **Validação Pré-Push Automatizada:**
   ```powershell
   .\tool\pre_push.ps1
   ```
   - O script executa `dart format --output=none --set-exit-if-changed lib test integration_test` e `flutter analyze`.
   - Em ambientes Windows com caminhos não-ASCII, o script monta automaticamente uma unidade virtual temporária para evitar falhas conhecidas de LSP do Flutter.
   - O exit code deve ser 0.

2. **Execução de Testes Automatizados Focados:**
   - Execute a suíte de testes do módulo ou subsistema alterado:
     ```powershell
     flutter test test/<modulo>/
     # Exemplo: flutter test test/audit_round2_features_test.dart
     ```
   - Garanta que todos os testes passem com exit code 0 sem falhas ou exceções não tratadas.

## 2. Checagem de Compatibilidade Multiplataforma e Web-Safety

- **Auditoria de Imports:**
  - Código executado ou alcançável pela Web (`kIsWeb`) nunca deve importar `dart:io` ou `package:sqlite3/sqlite3.dart` de maneira incondicional.
  - Utilize *conditional imports* seguindo o padrão da base:
    - `*_io.dart` para alvos nativos (Android, iOS, Windows, macOS, Linux).
    - `*_web.dart` para alvos Web (Wasm, IndexedDB).
    - Arquivo de barramento (`*.dart`) exportando a implementação condicional com base em `dart.library.io` ou `dart.library.js_interop`.
  - Verifique que `ENABLE_E2EE_SYNC` permaneça com `defaultValue: false` no código-fonte.

## 3. Desalocação e Ciclo de Vida de Recursos

- Garanta que conexões SQLite (`db.close()` / `db.dispose()`) sejam explicitamente fechadas em `stop()` ou `dispose()`.
- Verifique que `StreamSubscription` e `StreamController` / `Sink` sejam devidamente cancelados e fechados para respeitar `cancel_subscriptions` e `close_sinks`.

## 4. Padrão de Mensagens de Commit (Conventional Commits)

Adote mensagens descritivas seguindo a convenção:
- `feat(<escopo>): ...` para novas funcionalidades
- `fix(<escopo>): ...` para correções de bugs
- `chore(<escopo>): ...` para tarefas de manutenção, CI e infraestrutura
- `test(<escopo>): ...` para adição ou ajuste de testes
- `docs(<escopo>): ...` para documentação
- `refactor(<escopo>): ...` para refatorações sem alteração de comportamento externo
- `perf(<escopo>): ...` para otimizações de performance

## 5. Checklist para Abertura de Pull Request

- [ ] `.\tool\pre_push.ps1` executado e passou com exit code 0.
- [ ] Testes do módulo afetado (`flutter test test/...`) executados com sucesso.
- [ ] Nenhum import incondicional de `dart:io` ou `package:sqlite3/sqlite3.dart` em código Web.
- [ ] Conexões SQLite, sockets e streams fechados em `dispose()` / `stop()`.
- [ ] PR aberto com template preenchido (`.github/pull_request_template.md`).
