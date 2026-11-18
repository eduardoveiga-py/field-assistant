# Impact Assessment — Fases 0 & 1: Governança, CI/CD, E2EE Fail-Closed, Isolamento de Contas, Path Traversal e Backup Restore

- **Task IDs:** `FA-GOV-01`, `FA-CI-01`, `FA-SEC-01`, `FA-SEC-02`, `FA-SEC-03`, `FA-SEC-04`, `FA-SEC-09`, `FA-BAK-01`
- **Data:** 2026-11-17
- **Branch:** `stabilization/faes-master-program` (base `master` @ `47cc87d`)

---

## 1. Problema e Resultado Esperado
A auditoria baseline (`47cc87d`, nota 4,46/10) confirmou seis vulnerabilidades P0 ativas que inviabilizam o uso seguro de sincronização em nuvem e colocam em risco confidencialidade e integridade dos dados:
1. **E2EE fail-open (`FA-SEC-01`):** `SupabaseSyncService._processQueue()` captura falhas de `recordSync.write()` como warning e sempre grava `remotePayload` em texto claro via `sync_upsert_if_unchanged`; `_fetchRemoteChanges()` lê apenas tabelas plaintext; os 4 buckets de Storage fazem upload/download em texto claro ignorando `SyncPrivacyPolicy.unencryptedMediaAllowed == false`.
2. **Protocolo E2EE incompleto (`FA-SEC-02`, `FA-SEC-03`):** falta pull paginado por cursor monotônico (`server_seq`), `EncryptedRecordCheckpoint` não está integrado ao sync principal, `DELETE` não grava tombstone cifrado, `restoreVault()` cria silenciosamente um cofre remoto se ausente, `SupabaseEncryptedRecordTransport` tem fallback silencioso para tabelas experimentais e `EncryptedMedia` não está integrado aos 4 buckets.
3. **Contaminação cross-account (`FA-SEC-04`):** `E2eeService` espelha chaves entre `local_user` e qualquer `ownerId` autenticado (`copyOwnerKey`), permitindo que Conta B herde a chave da Conta A após logout/login; `AuthSplashScreen` invoca `sync()` sem validar `automatic_sync_owner_id` nem `demo_mode`.
4. **Path traversal (`FA-SEC-09`):** `saveMediaBytes()` em `lib/sync/media_bytes_io.dart` aceita qualquer `fileName`/`subDir` sem validação de contenção canônica.
5. **Restore destrutivo de identidade (`FA-BAK-01`):** `BackupService.restoreFromBackup()` sobrescreve chaves críticas de `app_kv_store` (`automatic_sync_owner_id`, cursores, checkpoints E2EE, flags de sessão) e reinjeta `sync_queue` antiga do backup.
6. **CI/CD permissivo (`FA-CI-01`):** `ci.yml` usa `permissions: contents: write` global, Actions por tag mutável, não executa `dart format --set-exit-if-changed` nem PGlite SQL tests em `master`/PRs.

## 2. Arquivos, Tabelas, RPCs e Fronteiras Afetados
- **Segurança & Sync:**
  - `lib/sync/sync_owner_guard.dart` (novo — `SyncOwnerGuard` centralizado)
  - `lib/sync/sync_privacy_policy.dart`
  - `lib/sync/crypto/e2ee_service.dart`
  - `lib/sync/crypto/encrypted_record_sync.dart`
  - `lib/sync/crypto/encrypted_record_checkpoint.dart`
  - `lib/sync/crypto/encrypted_media.dart`
  - `lib/sync/supabase_sync_service.dart`
  - `lib/sync/media_bytes_io.dart`
- **Auth & Navegação:**
  - `lib/ui/screens/auth_splash_screen.dart`
  - `lib/ui/main_navigation_shell.dart`
  - `lib/ui/screens/settings_screen.dart` (logout seguro + remoção de exposição indevida)
- **Backup:**
  - `lib/settings/backup_service.dart`
- **Banco / SQL:**
  - Nova migration versionada `supabase/migrations/20261117000000_e2ee_server_seq_pull_and_hardening.sql` (adiciona `server_seq BIGSERIAL`, índice `(owner_id, server_seq)` em `encrypted_records` e RPC `encrypted_records_pull_since` com RLS/`auth.uid()` estrito).
- **CI/CD:**
  - `.github/workflows/ci.yml`, `.github/workflows/validation.yml`, `.github/dependabot.yml`.

## 3. Casos Extremos e Modos de Falha
- Falha de rede ou exceção de cifra durante push: operação permanece `pending`/`failed` na `sync_queue`, zero escrita em tabelas plaintext ou Storage plaintext.
- Logout da Conta A seguido de login da Conta B no mesmo dispositivo: `SyncOwnerGuard` bloqueia sync enquanto `automatic_sync_owner_id != userB`; Conta B nunca lê/herda chave da Conta A via `local_user`.
- `restoreVault()` quando cofre remoto está ausente: lança `StateError` explícito (não cria cofre novo silenciosamente).
- `saveMediaBytes` recebendo `../../etc/passwd`, `..\evil.m4a`, `/abs/path`, `foo\0bar`, `subDir: '../outside'`: rejeita com `ArgumentError` sem criar/sobrescrever arquivos.
- Restore de backup contendo `automatic_sync_owner_id` de outra conta, checkpoints E2EE antigos e `sync_queue` antiga: preserva identidade/checkpoints/cursores locais e não reinjeta operações antigas da `sync_queue`.
- Exclusão lógica (`DELETE`) no modo E2EE: grava tombstone cifrado (`_tombstone: true`, `deletedAt`) com CAS e é aplicado atomicamente via `EncryptedRecordCheckpoint` no segundo dispositivo.

## 4. Plano de Testes e Evidências
- Testes unitários/integração Dart:
  - `test/sync/media_bytes_security_test.dart` (path traversal e gravação atômica)
  - `test/sync/account_isolation_test.dart` (`SyncOwnerGuard`, `E2eeService` sem espelhamento `local_user`, Conta A -> logout -> Conta B -> Conta A)
  - `test/sync/crypto/e2ee_sync_flow_test.dart` (reescrito para executar push/pull/delete/media reais, provando zero plaintext no wire)
  - `test/sync/crypto/e2ee_service_test.dart` e `test/sync/crypto/encrypted_record_sync_test.dart`
  - `test/backup/restore_identity_protection_test.dart` (proteção de `app_kv_store` e `sync_queue` no restore)
- Testes SQL PGlite:
  - `test/sql/production_e2ee_test.mjs` (estendido para `server_seq`, paginação, RLS cross-user e tombstones)
  - Todos os testes SQL existentes + suíte completa `flutter test` + `dart analyze lib test`.

## 5. Plano de Rollback e Recuperação
- Todas as alterações vivem na branch isolada `stabilization/faes-master-program`; rollback imediato via `git checkout master`.
- Migration SQL é estritamente aditiva (`ADD COLUMN IF NOT EXISTS server_seq`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`), sem `DROP` destrutivo de tabelas de produção até homologação completa em staging.
