# MATRIZ DE TESTES E CENÁRIOS DE INTEGRAÇÃO

## 1. Suíte Existente (496 Testes Aprovados)
- `test/appointments/calendar_sync_test.dart`: 23 testes (cenários 1–10 e A–D).
- `test/backup_service_test.dart`: 14 testes (TC-BAK-01 a TC-BAK-14).
- `test/counting_rules_test.dart`: 20 testes (TC-COUNT-01 a TC-COUNT-20).
- `test/supabase_sync_service_test.dart`: 13 testes (TC-SYNC-01 a TC-SYNC-13).
- `test/voice_notes_test.dart`: 15 testes.
- `test/widget_test.dart` e testes de telas: 411 testes.

---

## 2. Novos Cenários Adversariais da Missão de Estabilização

| Código do Teste | Arquivo de Teste | Objetivo e Validação |
|---|---|---|
| `TC-BAK-ADV-01` | `test/backup_service_test.dart` | **Staging e Rollback Seguro:** Sobrescrita de áudio existente com falha na transação comprova que o áudio original é recuperado intacto sem exclusão. |
| `TC-BAK-ADV-02` | `test/backup_service_test.dart` | **Limpeza de Staging:** Falha antes da confirmação garante que nenhuma mídia intermediária órfã permaneça em disco. |
| `TC-BAK-ADV-03` | `test/backup_service_test.dart` | **Armazenamento Indisponível:** Falha ao obter diretório de documentos dispara `StorageUnavailableException` e cancela operação sem usar `/tmp`. |
| `TC-BAK-ADV-04` | `test/backup_service_test.dart` | **Snapshot na Web:** Valida que o snapshot pré-restauração é gravado e verificado no KV store sob `kIsWeb`. |
| `TC-SYNC-ADV-01` | `test/supabase_sync_service_test.dart` | **Cursor Determinístico:** 150 registros remotos com o mesmo timestamp exato são puxados sem pular nenhum registro na fronteira de página. |
| `TC-SYNC-ADV-02` | `test/supabase_sync_service_test.dart` | **Upload de Áudio Não Confirmado:** Falha no upload Storage mantém a nota de voz na fila e NÃO a marca como concluída no SQLite. |
| `TC-SYNC-ADV-03` | `test/supabase_sync_service_test.dart` | **Download Pendente Resiliente:** Falha no download de mídia cria registro em `pending_media_downloads` e permite recuperação posterior via `retryPendingMediaDownloads()`. |
| `TC-SYNC-ADV-04` | `test/repository_database_test.dart` | **Alterações Indiretas Atômicas:** `createVisit()` atualiza `people` e gera atomicamente uma operação `UPDATE` para `people` na `sync_queue`. |
| `TC-APPLE-ADV-01` | `test/appointments/calendar_sync_test.dart` | **Proteção contra Falsa Exclusão Parcial:** Consulta retornando subconjunto reduzido (>25% sumido sem exclusão confirmada) não apaga vínculos ministeriais. |
| `TC-APPLE-ADV-02` | `test/appointments/calendar_sync_test.dart` | **Fingerprint com Recorrência:** Alteração de regra de recorrência altera o hash SHA-256 e aciona reconciliação. |
| `TC-DB-ADV-01` | `test/database_integrity_test.dart` | **Integridade de Chaves Estrangeiras:** Tentativa de violar Foreign Key com `PRAGMA foreign_keys = ON;` lança exceção do SQLite. |
| `TC-DB-ADV-02` | `test/database_integrity_test.dart` | **Concorrência WAL Mode:** Leituras simultâneas durante escrita pesada não geram bloqueio de banco de dados. |
