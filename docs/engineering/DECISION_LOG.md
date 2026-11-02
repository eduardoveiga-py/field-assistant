# REGISTRO HISTÓRICO DE DECISÕES DE ENGENHARIA (ADRs)

Este registro preserva o contexto, as alternativas ponderadas e as consequências de todas as decisões arquiteturais tomadas durante a estabilização e evolução do **Field Assistant**.

---

## ADR-001: Eliminação de Fallback Silencioso para `Directory.systemTemp`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Em `lib/settings/backup_service.dart`, `_getDocsDir()` capturava `MissingPluginException` e retornava `Directory.systemTemp`.
- **Decisão:** Rejeitar qualquer uso de diretórios temporários para snapshots de segurança e arquivos de mídia. Lançar explicitamente `StorageUnavailableException`.
- **Justificativa:** O sistema operacional pode expurgar o diretório temporário a qualquer momento para liberar espaço, destruindo notas de voz e inviabilizando restaurações.
- **Consequências:** Aplicação falha de maneira controlada com aviso de erro em vez de perder dados silenciosamente. Validado por `TC-BAK-ADV-03`.

---

## ADR-002: Staging em Três Etapas para Restauração de Áudios
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Arquivos de notas de voz eram descompactados diretamente na pasta final `/voice_notes/`. Se a transação do banco falhasse em seguida, o bloco catch executava `deleteSync()`, apagando áudios legítimos pré-existentes.
- **Decisão:** Criar um fluxo transacional de staging:
  1. Descompactar para `safety_staging/<uuid>/`.
  2. Mover arquivos pré-existentes que serão substituídos para `safety_audio_backup/<uuid>/`.
  3. Mover atomicamente do staging para `/voice_notes/` apenas após o commit do SQLite.
  4. Em caso de falha no commit, restaurar os originais do backup e limpar o staging.
- **Justificativa:** Garante transacionalidade mútua entre o sistema de arquivos e o banco relacional.
- **Consequências:** Zero perda de mídias durante restaurações com falha. Validado por `TC-BAK-ADV-01` e `TC-BAK-ADV-02`.

---

## ADR-003: Ordenação Determinística Composta no Cursor de Sincronização Supabase
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** A paginação remota em `lib/sync/supabase_sync_service.dart` ordenava apenas por `updated_at`. Quando múltiplos registros compartilhavam o mesmo milissegundo, a fronteira de página pulava registros não processados.
- **Decisão:** Ordenar estritamente por `.order('updated_at', ascending: true).order('id', ascending: true)`. O cursor no KV store só avança até o carimbo de data/hora do último registro efetivamente aplicado no banco local.
- **Justificativa:** Elimina perda silenciosa de dados em cargas em lote.
- **Consequências:** Sincronização incremental 100% determinística. Validado por `TC-SYNC-ADV-01`.

---

## ADR-004: Enfileiramento Obrigatório de Mutações Indiretas na Outbox
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O método `createVisit()` em `lib/database/repository.dart` atualizava `people` (alterando `lastContactAt` e `nextActionNote`), mas só enfileirava a operação para `visits`. O outro aparelho recebia a visita, mas o contato permanecia desatualizado.
- **Decisão:** Toda mutação em qualquer tabela secundária dentro de uma transação local deve enfileirar sua respectiva operação na `sync_queue` contendo snapshot `baseData`.
- **Justificativa:** Previne divergências de estado entre múltiplos dispositivos.
- **Consequências:** Atualização síncrona de metadados em todos os nós. Validado por `TC-SYNC-ADV-04`.

---

## ADR-005: Ativação Obrigatória de `PRAGMA foreign_keys = ON;` e `WAL`
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O SQLite nativo via Drift desativa por padrão a validação de chaves estrangeiras se não configurado explicitamente no callback de conexão.
- **Decisão:** Configurar o callback `setup` no `NativeDatabase.createInBackground`:
  ```dart
  rawDb.execute('PRAGMA foreign_keys = ON;');
  rawDb.execute('PRAGMA journal_mode = WAL;');
  rawDb.execute('PRAGMA synchronous = NORMAL;');
  rawDb.execute('PRAGMA busy_timeout = 5000;');
  ```
- **Justificativa:** Garante integridade referencial física e previne bloqueios de leitura concorrente.
- **Consequências:** Tentativas de criar registros órfãos são rejeitadas pelo motor SQLite. Validado por `TC-DB-ADV-01` e `TC-DB-ADV-02`.

---

## ADR-006: Proteção contra Consultas Parciais Truncadas no Apple EventKit
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** Quando o iOS ou `device_calendar` sofria limitação ou retornava um subconjunto parcial de eventos, o sincronizador interpretava os eventos ausentes como exclusões externas e apagava os vínculos pastorais.
- **Decisão:** Detectar anomalias de exclusão em massa (>25% de ausência súbita sem exclusão confirmada) e suspender a remoção automática, solicitando confirmação.
- **Justificativa:** Protege os dados ministeriais contra instabilidades transitórias da API do sistema operacional.
- **Consequências:** Zero perda indevida de agendamentos. Validado por `TC-APPLE-ADV-01`.

---

## ADR-007: Inclusão da Regra de Recorrência no Fingerprint SHA-256
- **Data:** Outubro de 2026
- **Status:** Aprovado e Implementado
- **Contexto:** O cálculo do hash de alteração de eventos de calendário ignorava a string de regra de recorrência (`RRULE`). Alterações de frequência não eram detectadas.
- **Decisão:** Incluir o campo `recurrenceRuleStr` determinístico no cálculo de `computeEventFingerprint()`.
- **Justificativa:** Garante reconciliação exata entre compromissos recorrentes e avulsos.
- **Consequências:** Reconciliação imediata ao alterar repetição de compromissos. Validado por `TC-APPLE-ADV-02`.

---

## ADR-008: Não Substituição do Hourglass para Gestão de Territórios
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** O usuário utiliza a plataforma consolidada Hourglass para gerenciamento cartográfico e de designação de territórios.
- **Decisão:** Manter o escopo do mapa no Field Assistant estritamente como visualizador geográfico de contatos próprios (`contacts_map_screen.dart`), sem tentar reinventar módulos de controle de congregação do Hourglass.
- **Justificativa:** Evita duplicação de esforço e preserva a especialização ministerial do aplicativo.

---

## ADR-009: Proibição de Migrações Destrutivas por Feature Flags
- **Data:** Novembro de 2026
- **Status:** Aprovado e Mantido
- **Contexto:** Em `customize_features_screen.dart`, o usuário pode desativar telas ou submódulos (ex: experiências, publicações, notas de voz).
- **Decisão:** A desativação de uma funcionalidade na interface apenas oculta seus pontos de entrada na UI. É expressamente proibido disparar `DROP TABLE` ou `DELETE` em dados históricos. Ao reativar a flag, todos os dados devem reaparecer intactos.
- **Justificativa:** Preservação categórica do patrimônio de registros do publicador.
