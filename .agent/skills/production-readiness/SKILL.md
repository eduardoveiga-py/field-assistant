---
name: production-readiness
description: Critérios rigorosos de prontidão para produção, métricas de Release Candidate e guardrails de estabilidade técnica.
---

# Skill: Prontidão para Produção (Production Readiness)

Esta skill estabelece a matriz de critérios de aceitação e os guardrails obrigatórios para promoção de versões do **Field Assistant** ao estado de Release Candidate e Produção.

## 1. Critérios Mandatórios de Engenharia

### Análise Estática
- O comando `dart analyze lib test --fatal-infos` deve retornar rigorosamente **0 issues** (0 erros, 0 avisos, 0 lints, 0 infos).
- Toda regra do `analysis_options.yaml` deve ser estritamente cumprida sem anotações de ignore espúrias.

### Cobertura e Execução de Testes
- 100% dos testes automatizados devem ser executados com aprovação unânime.
- Suíte completa de testes unitários, testes de repositório, testes de UI/widget, testes adversariais e testes integrados de sincronização (694+ testes).
- Execução sequencial determinística: `flutter test --concurrency=1` sem flaky tests e sem vazamento de estado entre testes.

### Integridade do Banco de Dados Local (Drift SQLite / Drift Wasm)
- Conexão nativa com `PRAGMA foreign_keys = ON;`, `PRAGMA journal_mode = WAL;`, `PRAGMA synchronous = NORMAL;` e `busy_timeout = 5000;`.
- Migrações incrementais versionadas sem blocos `catch (_) {}` silenciosos, reportando exceções com `AppLogger.error` e `rethrow`.
- Na Web, compilação com `drift/wasm.dart`, armazenamento persistente em IndexedDB e worker canônico único `web/drift_worker.js`.

### Sincronização Multi-Dispositivo Offline-First (10 Cenários P0)
A sincronização entre dispositivos é requisito inegociável da v1. Deve cumprir os 10 cenários de aceitação:
1. Sincronização online bidirecional entre 2 dispositivos com paridade completa.
2. Fila outbox (`sync_queue`) com persistência transacional durável pós-reinicialização.
3. Mesclagem determinística de campos distintos (3-way merge) sem perda de dados.
4. Detecção e visibilidade explícita de conflitos em edições no mesmo campo.
5. Detecção semântica de compromissos concorrentes na agenda pós-sync (marcação de conflito e provisório).
6. Soft delete via tombstones com barreira contra ressurreição por nós atrasados.
7. Mídia de notas de voz enviada para bucket privado de Storage sem expor caminhos locais.
8. Isolamento multi-tenant absoluto via RLS (`owner_id = auth.uid()`) e bloqueio de `service_role`.
9. Recuperação resiliente de falhas de rede transitórias e expiração de sessão com backoff.
10. Instalação limpa (bootstrap) com full pull inicial das 10 tabelas sincronizadas.

## 2. Matriz de Classificação de Riscos e Bloqueadores
- **P0 (Crítico):** Bloqueia lançamento e integridade dos dados (sync corrompido, vazamento de credenciais, perda de dados). Deve ser 100% resolvido antes do gate pass.
- **P1 (Alto):** Falhas em fluxos de apoio (concorrência de agenda, travamento de microfone, falhas em migrações). Deve ser 100% resolvido e testado no código.
- **P2 (Médio):** Débitos de manutenibilidade e modularização de código. Devem estar endereçados sem quebra de contratos públicos.

## 3. Identificação de Dependências Externas de Ambiente
- Toda pendência não resolvida no código deve ser categoricamente identificada como dependência externa de infraestrutura:
  - Geração de `.ipa` / Archive iOS e assinatura de código em runner macOS com conta Apple Developer ativa.
  - Testes de campo em hardware físico Apple (iPhone/iPad) para validação de microfone e EventKit.
