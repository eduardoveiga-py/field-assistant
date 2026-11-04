# Infraestrutura de Testes End-to-End (E2E) P0/P1 — Ministério Pessoal

Este documento detalha a arquitetura, contratos e suíte de testes ponta a ponta (E2E) Dual Track cobrindo os requisitos críticos P0/P1 de todas as 6 fases da aplicação:
1. **Fase 1**: Google Calendar OAuth & Sync Guardrails (HTTP 410, read-only, logging hygiene)
2. **Fase 2**: Supabase Auth & Multi-tenant Identity (fail-safe offline, RLS, sanitização outbox)
3. **Fase 3**: Sincronização das 18 Tabelas de Domínio e Privacidade do Supabase Storage
4. **Fase 4**: Conexão Web Database Fail-Closed e Particionamento por UID
5. **Fase 5**: Correções de Plataforma e Limites de Hardware Real (GPS Haversine, limite de 30s no microfone)
6. **Fase 6**: Integridade do Banco de Dados e Configurações de Alto Contraste (`sunModeTheme`)

---

## 1. Arquitetura e Contratos de Simulação (`p0_e2e_contracts.dart`)

Para assegurar testes realistas sem depender de servidores de staging ou serviços externos frágeis em CI/CD, a suíte implementa simulações contratuais completas:

### 1.1 `MockSupabaseFullDomainServer`
- **18 Tabelas de Domínio**: Suporte a `people`, `visits`, `bible_studies`, `study_participants`, `study_sessions`, `appointments`, `activity_records`, `voice_notes`, `phone_contacts`, `territory_landmarks`, `family_ties`, `ministry_experiences`, `person_photos`, `person_publications`, `research_articles`, `research_tags`, `territory_sectors` e `student_manual_order`.
- **Row Level Security (RLS)**: Rejeição com HTTP 403 / vazio quando `owner_id != auth.uid()`.
- **Soft Delete / Tombstones**: Propagação de `deleted_at` com bloqueio determinístico de ressuscitação por nós com relógio atrasado.
- **Paginação por Range**: Suporte ao cabeçalho `Range: items=0-99` para sincronização em lotes.
- **Storage Privado Seguro**: Emulação dos buckets `voice_notes` e `person_photos` com RLS por prefixo de pasta (`auth.uid()/filename`).
- **Simulador de Falha de Rede**: Chave `simulateNetworkFailure` para testes de resiliência e backoff.

### 1.2 `MultiDeviceSimEnvironment`
- Cria ambientes isolados representando múltiplos nós concorrentes (ex: Celular do Ancião, Tablet da Pioneira, Navegador Web compartilhado).
- Cada dispositivo opera seu próprio banco de dados SQLite Drift isolado na memória com chaves estrangeiras ativadas (`NativeDatabase.memory()`), repositório de domínio e motor de sincronização.

---

## 2. Estrutura de Diretórios da Suíte E2E

```
test/e2e/p0_p1/
├── p0_e2e_contracts.dart              # Servidor PostgREST simulado, storage e multi-device harness
├── p0_tier1_feature_coverage_test.dart # Tier 1: 15 testes cobrindo Fases 1 a 6
├── p0_tier2_boundary_corner_test.dart  # Tier 2: 8 testes de limites, timeouts e erros de borda
├── p0_tier3_cross_feature_test.dart    # Tier 3: 5 testes combinados entre módulos
├── p0_tier4_real_world_scenarios_test.dart # Tier 4: 4 jornadas completas de uso real
└── p0_p1_e2e_master_test.dart         # Runner mestre executando os 32 testes de ponta a ponta
```

---

## 3. Matriz de Casos de Teste (32 Testes)

### Tier 1: Cobertura Funcional P0/P1 (15 Testes)
| ID | Descrição | Fase |
|---|---|---|
| `TC-P0-GCAL-01` | HTTP 410 (Sync Token Expirado) aciona full sync e conclui com sucesso | Fase 1 |
| `TC-P0-GCAL-02` | Calendários com accessRole somente-leitura são marcados como `isReadOnly: true` | Fase 1 |
| `TC-P0-GCAL-03` | Falhas de API retornam `CalendarSyncResult` estruturado sem lançar exceções | Fase 1 |
| `TC-P0-AUTH-01` | Estado de Supabase desconfigurado opera offline sem lançar AssertionError | Fase 2 |
| `TC-P0-AUTH-02` | Isolamento multi-tenant: registros possuem `owner_id` estrito do usuário | Fase 2 |
| `TC-P0-AUTH-03` | Fila outbox local sanitiza `owner_id` arbitrário enviado pelo cliente | Fase 2 |
| `TC-P0-SYNC-01` | Todas as 18 tabelas de domínio são reconhecidas na matriz de sincronização | Fase 3 |
| `TC-P0-SYNC-02` | Exclusão lógica propaga `deleted_at` tombstone sem DELETE físico no PostgREST | Fase 3 |
| `TC-P0-SYNC-03` | Storage Privado: sanitização remove caminhos absolutos locais do payload | Fase 3 |
| `TC-P0-WEBDB-01`| Conexão fail-closed: falha crítica não executa gravações silenciosas perdidas | Fase 4 |
| `TC-P0-WEBDB-02`| Partição de banco por UID gera namespace isolado | Fase 4 |
| `TC-P0-PLAT-01` | GeolocationHelper calcula distância Haversine real e não usa coordenadas fixas | Fase 5 |
| `TC-P0-PLAT-02` | Gravação de voz para fisicamente aos 30 segundos no hardware do serviço | Fase 5 |
| `TC-P0-SEC-01`  | `PRAGMA foreign_keys` está ativo e impede orfandade referencial | Fase 6 |
| `TC-P0-SEC-02`  | Preferência de alto contraste persiste em `AppKvStore` sobrevivendo a reinicializações | Fase 6 |

### Tier 2: Casos de Borda e Limites (8 Testes)
| ID | Descrição |
|---|---|
| `TC-P0-CORNER-01` | Fila de outbox vazia completa `processQueue()` sem requisições desnecessárias |
| `TC-P0-CORNER-02` | Token do Google Calendar expirado (HTTP 401) retorna erro acionável |
| `TC-P0-CORNER-03` | Sessão Supabase expirada bloqueia mutações e reporta `authenticationExpired` |
| `TC-P0-CORNER-04` | Queda de rede durante envio incrementa tentativas e calcula backoff clamped |
| `TC-P0-CORNER-05` | Mutação que atinge 5 tentativas de falha é marcada como `failed` sem travar fila |
| `TC-P0-CORNER-06` | Permissão de microfone negada lança exceção explícita sem criar gravações fantasmas |
| `TC-P0-CORNER-07` | Cursor composto `(updated_at, id)` resolve ordenação estrita mesmo com timestamps idênticos |
| `TC-P0-CORNER-08` | Payload JSON com aspas, caracteres especiais e quebras preserva integridade |

### Tier 3: Combinações Cross-Feature (5 Testes)
| ID | Descrição |
|---|---|
| `TC-P0-CROSS-01` | Troca de conta limpa storage seguro e desvincula calendário sem vazamento de tokens |
| `TC-P0-CROSS-02` | Dados criados offline antes do login são associados à conta e sincronizados |
| `TC-P0-CROSS-03` | Nota de voz com limite de hardware é sanitizada e enviada para bucket privado com RLS |
| `TC-P0-CROSS-04` | Exclusão lógica com tombstone rejeita ressurreição por edição concorrente desatualizada |
| `TC-P0-CROSS-05` | Compromissos concorrentes com sobreposição de horário sinalizam colisão pós-sync |

### Tier 4: Cenários do Mundo Real (4 Testes)
| ID | Descrição |
|---|---|
| `TC-P0-SCENARIO-01` | **Husband & Wife 2-Device Journey**: Sincronização multi-dispositivo familiar com isolamento estrito por RLS e convergência mútua |
| `TC-P0-SCENARIO-02` | **Shared Browser Account Switch**: Alternância de contas no mesmo navegador garante banco particionado por UID e zero vazamento |
| `TC-P0-SCENARIO-03` | **Rural Ministry Disconnected Morning**: Jornada ministerial matinal 100% offline com reconexão noturna e convergência total |
| `TC-P0-SCENARIO-04` | **90-Day Inactivity Recovery**: Reabertura após inatividade prolongada com recuperação de erro HTTP 410 no calendário |

---

## 4. Instruções de Execução

### Execução da Suíte E2E Mestre:
```bash
flutter test test/e2e/p0_p1/p0_p1_e2e_master_test.dart
```

### Execução por Tiers Individuais:
```bash
flutter test test/e2e/p0_p1/p0_tier1_feature_coverage_test.dart
flutter test test/e2e/p0_p1/p0_tier2_boundary_corner_test.dart
flutter test test/e2e/p0_p1/p0_tier3_cross_feature_test.dart
flutter test test/e2e/p0_p1/p0_tier4_real_world_scenarios_test.dart
```

### Análise Estática (Zero Warnings / Zero Lints):
```bash
dart analyze test/e2e/p0_p1/
```
