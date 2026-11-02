# REGISTRO DE DECISÕES DE ENGENHARIA (ADRs)

## ADR-001: Eliminação de Fallback Silencioso para `Directory.systemTemp`
- **Contexto:** `_getDocsDir()` em `backup_service.dart` recorria a `Directory.systemTemp` quando ocorria exceção na obtenção do diretório de documentos.
- **Decisão:** Rejeitar categoricamente o uso de armazenamento temporário para snapshots e áudios. Lançar `StorageUnavailableException` de forma explícita caso o sistema operacional não forneça armazenamento persistente seguro.
- **Justificativa:** Armazenamento temporário pode ser limpo pelo SO a qualquer instante, destruindo snapshots de recuperação e notas de voz do usuário.

---

## ADR-002: Staging em Três Etapas para Restauração de Áudios
- **Contexto:** Na implementação anterior, arquivos de áudio eram escritos diretamente em `voice_notes/`. Se a transação SQLite falhasse depois, o bloco de captura chamava `deleteSync()`, apagando arquivos que já existiam antes da restauração.
- **Decisão:** Implementar staging:
  1. Extrair para pasta temporária de staging (`safety_staging/<id>/`).
  2. Fazer backup prévio de qualquer arquivo existente que vá ser substituído (`safety_audio_backup/<id>/`).
  3. Mover atomicamente para o destino apenas após a transação do banco ser confirmada.
  4. Em caso de falha, reverter os arquivos substituídos a partir do backup e limpar o staging.
- **Justificativa:** Garante transacionalidade real de ponta a ponta entre o banco relacional e o sistema de arquivos.

---

## ADR-003: Ordenação Determinística Composta no Cursor Supabase
- **Contexto:** A paginação remota ordenava apenas por `updated_at`. Registros com timestamps idênticos podiam ser pulados na fronteira de página.
- **Decisão:** Ordenar estritamente por `.order('updated_at', ascending: true).order('id', ascending: true)`. O avanço do cursor no `appKvStore` ocorre apenas até o timestamp do último registro persistido com sucesso no SQLite local.
- **Justificativa:** Elimina perda silenciosa de dados em sincronizações de múltiplos registros.

---

## ADR-004: Enfileiramento Obrigatório de Alterações Indiretas na Outbox
- **Contexto:** Métodos como `createVisit()` atualizavam a tabela `people` (ex: `lastContactAt`) mas só enfileiravam uma operação de sincronização para `visits`. O outro dispositivo recebia a visita mas os metadados da pessoa ficavam desatualizados.
- **Decisão:** Toda mutação local em qualquer entidade dentro de uma transação deve registrar sua respectiva operação na `sync_queue` com seu snapshot `baseData`.
- **Justificativa:** Garante coerência entre múltiplos dispositivos.

---

## ADR-005: Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL`
- **Contexto:** Drift no SQLite nativo não habilitava verificações de chave estrangeira por padrão.
- **Decisão:** Configurar o callback `setup` no `NativeDatabase.createInBackground` para forçar `PRAGMA foreign_keys = ON;` e `PRAGMA journal_mode = WAL;`.
- **Justificativa:** Impede registros órfãos e melhora a concorrência em segundo plano.
