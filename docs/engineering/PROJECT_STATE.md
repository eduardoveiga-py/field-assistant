# ESTADO DO PROJETO: FIELD ASSISTANT

- **Branch de Estabilização:** `stabilization/definitive-hardening`
- **Branch Base:** `master`
- **Commit Base:** `6bd1e6cc72bb469ea76fe6cb749f7b15fb7986f3`
- **Schema Drift/SQLite:** Versão `4`
- **Total de Testes Automatizados:** 508 testes aprovados (100% de sucesso)
- **Status do Build Web:** Concluído com sucesso (`flutter build web --release`)
- **Status da Análise Estática:** 0 issues (`dart analyze lib test --fatal-infos`)
- **Status da Formatação:** 100% em conformidade (`dart format --output=none --set-exit-if-changed lib test`)

---

## 1. Visão Geral da Arquitetura
O **Field Assistant** é uma aplicação Flutter para organização do ministério pessoal e pastoral:
- **Offline-First:** O SQLite local via Drift é a fonte da verdade primária e imediata em qualquer operação.
- **Sincronização:** Supabase com protocolo de fila de saída (`sync_queue`), mesclagem de 3 vias com detecção determinística de conflitos (`SyncEngine.mergeEntities()`) e RLS no PostgreSQL remoto.
- **Calendário:** Reconciliação bidirecional com Google Calendar e Apple Calendar (via EventKit nativo / `device_calendar`), identificando alterações por fingerprint SHA-256 e protegendo integridade ministerial.
- **Backup & Restauração:** Criptografia simétrica AES-GCM (256 bits) com PBKDF2, snapshots automáticos de segurança e staging atômico de mídias de áudio.

---

## 2. Mapa de Módulos e Componentes

| Módulo | Caminho | Responsabilidade |
|---|---|---|
| **Database** | `lib/database/` | `app_database.dart`, `tables.dart`, `repository.dart`, conexões nativa e web com Foreign Keys e WAL mode. |
| **Settings / Backup** | `lib/settings/` | `backup_service.dart`, exportação/importação cifrada, prévias e snapshots de segurança em 3 estágios. |
| **Sync Engine** | `lib/sync/` | `sync_engine.dart`, `supabase_sync_service.dart`, controle de fila, cursor estável e upload/download de áudio. |
| **Appointments / Calendar** | `lib/appointments/` | `calendar_sync_coordinator.dart`, `apple_eventkit_provider.dart`, `google_calendar_provider.dart`. |
| **Dashboard / Rules** | `lib/dashboard/` | `counting_rules.dart`, `student_priority_engine.dart`. |
| **UI** | `lib/ui/` | Telas de pessoas, detalhes, estudos, mapa, agenda, hoje e configurações. |
| **Voice Notes** | `lib/voice_notes/` | Gravação, ditado, transcrição e briefing ministerial de portas. |

---

## 3. Estado Atual das Fases da Missão

- [x] **Fase 1 — Diagnóstico, Blindagem Inicial e Memória Técnica**
- [x] **Fase 2 — Backup e Recuperação Transacional à Prova de Falhas**
- [x] **Fase 3 — Sincronização Supabase: Cursor Estável, Áudio Resiliente e Outbox Completa**
- [x] **Fase 4 — Apple EventKit: Blindagem contra Falsas Exclusões e Fingerprint Robusto**
- [x] **Fase 5 — Banco de Dados, Segurança e Integridade Global**
- [x] **Fase 6 — Bateria de Testes Globais, Análise Estática, Ajustes de UI e Conclusão**
