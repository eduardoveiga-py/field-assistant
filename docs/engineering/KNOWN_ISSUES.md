# MATRIZ DE PROBLEMAS CONHECIDOS E STATUS DE MITIGAÇÃO

| ID | Área | Problema | Causa Raiz | Gravidade | Arquivo(s) | Status |
|---|---|---|---|---|---|---|
| **ISSUE-01** | Backup | Fallback para `Directory.systemTemp` | `_getDocsDir()` captura `MissingPluginException` e retorna diretório temp | Crítica | `lib/settings/backup_service.dart` | RESOLVIDO E TESTADO (`TC-BAK-ADV-03`) |
| **ISSUE-02** | Backup | Snapshot ignorado na Web | Bloco `if (!kIsWeb)` salta criação de snapshot em `commitRestore()` | Alta | `lib/settings/backup_service.dart` | RESOLVIDO E TESTADO (`TC-BAK-ADV-04`) |
| **ISSUE-03** | Backup | Destruição de áudios originais no rollback | `createdAudioFiles` acumula arquivos sobrescritos e chama `deleteSync()` no catch | Crítica | `lib/settings/backup_service.dart` | RESOLVIDO E TESTADO (`TC-BAK-ADV-01`, `TC-BAK-ADV-02`) |
| **ISSUE-04** | Sync | Paginação sem tie-breaker determinístico | Query remota ordena apenas por `updated_at` | Alta | `lib/sync/supabase_sync_service.dart` | RESOLVIDO E TESTADO (`TC-SYNC-ADV-01`) |
| **ISSUE-05** | Sync | Upload de áudio falho marcado como sucesso | `_uploadVoiceNoteAudio()` falha mas `markSyncOperationSuccess` é chamado | Crítica | `lib/sync/supabase_sync_service.dart` | RESOLVIDO E TESTADO (`TC-SYNC-ADV-02`) |
| **ISSUE-06** | Sync | Download de áudio silenciosamente descartado | `_downloadVoiceNoteAudio()` tem `catch (_)` sem registro de pendência | Alta | `lib/sync/supabase_sync_service.dart` | RESOLVIDO E TESTADO (`TC-SYNC-ADV-03`) |
| **ISSUE-07** | Sync / DB | Alterações indiretas em `people` não enfileiradas | `createVisit()` atualiza `people` sem chamar `_recordSyncOperation` para `people` | Crítica | `lib/database/repository.dart` | RESOLVIDO E TESTADO (`TC-SYNC-ADV-04`) |
| **ISSUE-08** | Calendar | Falsas exclusões em consultas parciais | `isMassDeletionAnomaly` só protege `events.isEmpty` | Alta | `lib/appointments/apple_eventkit_provider.dart` | RESOLVIDO E TESTADO (`TC-APPLE-ADV-01`) |
| **ISSUE-09** | Calendar | Fingerprint não recebe regra de recorrência | Parâmetro `recurrenceRule` omitido nas chamadas de `computeEventFingerprint` | Média | `lib/appointments/apple_eventkit_provider.dart` | RESOLVIDO E TESTADO (`TC-APPLE-ADV-02`) |
| **ISSUE-10** | Database | SQLite sem validação de chaves estrangeiras | Falta de callback `setup` no `NativeDatabase` emitindo `PRAGMA foreign_keys = ON;` | Alta | `lib/database/connection/native.dart` | Em correção (Fase 5) |
