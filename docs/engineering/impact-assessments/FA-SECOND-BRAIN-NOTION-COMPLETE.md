# Impact Assessment & Architecture Design — Base de Conhecimento Segundo Cérebro Completa (8 Pilares Estilo Notion)

- **Task ID:** `FA-SECOND-BRAIN-NOTION-COMPLETE`
- **Branch Base:** `feat/persistent-e2ee-email-second-brain`
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `.agents/skills/flutter-drift-architecture/SKILL.md`, `.agents/skills/offline-first-sync/SKILL.md`, `.agents/skills/mobile-ux-accessibility/SKILL.md`

---

## 1. Problema Observado & Resultado Esperado

Embora o módulo Base de Conhecimento já possua Notas, Perguntas, Documentos, Recursos, Cartas/Atas e marcação JW Library (`<u style=...>` / `app://ref/...`), faltam os 8 componentes centrais de um Segundo Cérebro estilo Notion completo, integrado ao fluxo ministerial e sincronizado offline-first/E2EE:
1. **Backlinks bidirecionais** ("Mencionado em...").
2. **Autocomplete inline `[[`** para referências/wikilinks e **menu `/` slash commands** no editor rico.
3. **Camada P.A.R.A. "Áreas" + Subpáginas hierárquicas (`parentNoteId`)** com breadcrumb e navegação em árvore.
4. **Views estilo Notion (`Lista`, `Tabela`, `Kanban`, `Galeria`) + Propriedades customizadas + Blocos ricos** (`Toggle`/`<details>`, `Callout` `[!NOTE]`/`[!TIP]`/`[!IMPORTANT]`/`[!WARNING]`, `Tabelas` Markdown editáveis/renderizadas e `Checklists` interativas clicáveis na leitura).
5. **Importador do Notion (`.zip`, `.md`, `.csv`)** com reconstrução de áreas, subpáginas, tags, propriedades e conversão de links internos para `app://ref/note/...`.
6. **Revisão Semanal guiada + Revisão Espaçada (SM-2 Lite)** integrada para Notas e Dúvidas teocráticas.
7. **Busca Full-Text com FTS5** (Nativo via SQLite FTS5 `unicode61 remove_diacritics 2`; Web PWA via índice tokenizado normalizado sem acentos usando *conditional imports* `_io.dart`/`_web.dart`) indexando também **tags e texto extraído de PDFs** anexados em `KnowledgeDocuments`.
8. **Sincronização ativa multi-dispositivos E2EE** abrangendo áreas, backlinks, subpáginas, propriedades e estado de revisão entre iOS, Android, Windows e Web PWA.

---

## 2. Esquema Drift v9 & Impacto de Migração

Unificado com `FA-WEB-E2EE-EMAIL-SYNC` em **uma única migração atômica v8 -> v9**:

### Novas Tabelas (sincronizadas E2EE via `encrypted_records`)
1. **`KnowledgeAreas` (`knowledge_areas`):**
   - `id` (TEXT PK), `name` (TEXT), `description` (TEXT?), `iconName` (`icon_name`, TEXT?), `colorHex` (`color_hex`, TEXT?), `sortOrder` (`sort_order`, INTEGER default 0), `isArchived` (`is_archived`, BOOLEAN default false), `createdAt`, `updatedAt`, `deletedAt`, `revision`.
2. **`KnowledgeLinks` (`knowledge_links`):**
   - `id` (TEXT PK), `sourceType` (`source_type`, TEXT), `sourceId` (`source_id`, TEXT), `targetType` (`target_type`, TEXT), `targetId` (`target_id`, TEXT), `targetUri` (`target_uri`, TEXT), `anchorText` (`anchor_text`, TEXT), `createdAt`, `updatedAt`, `deletedAt`, `revision`.
   - Índices SQLite: `(target_type, target_id, deleted_at)` e `(source_type, source_id, deleted_at)`.

### Novas Colunas em Tabelas Existentes (todas nullable ou com `DEFAULT` seguro)
- `Projects`: `areaId` (`area_id` TEXT NULL).
- `KnowledgeNotes`:
  - `areaId` (`area_id` TEXT NULL)
  - `parentNoteId` (`parent_note_id` TEXT NULL)
  - `propertiesJson` (`properties_json` TEXT NOT NULL DEFAULT `'{}'`)
  - `reviewLevel` (`review_level` INTEGER NOT NULL DEFAULT 0)
  - `nextReviewAt` (`next_review_at` INTEGER NULL)
  - `lastReviewedAt` (`last_reviewed_at` INTEGER NULL)
- `KnowledgeQuestions`:
  - `areaId` (`area_id` TEXT NULL)
  - `reviewLevel` (`review_level` INTEGER NOT NULL DEFAULT 0)
  - `nextReviewAt` (`next_review_at` INTEGER NULL)
  - `lastReviewedAt` (`last_reviewed_at` INTEGER NULL)
- `KnowledgeDocuments`:
  - `areaId` (`area_id` TEXT NULL)
  - `extractedText` (`extracted_text` TEXT NULL)
- `KnowledgeResources`:
  - `areaId` (`area_id` TEXT NULL)

### FTS5 Nativo + Fallback Web
- Gerenciado dinamicamente fora de `@DriftDatabase` por `KnowledgeSearchIndex` (`lib/knowledge/knowledge_search_index.dart` + `_io.dart` / `_web.dart`) para evitar incompatibilidades WASM em navegadores sem FTS5 e respeitar Web-safety estrita (zero import de `dart:io` ou `sqlite3` na Web).
- Extração de texto PDF em Dart puro (`PurePdfTextExtractor` usando `package:archive` `ZLibDecoder` para streams `/FlateDecode` e parser de operadores `BT..ET` `Tj`/`TJ`, sem dependências novas e 100% Web-safe; PDFs exclusivamente baseados em imagem/scan sem camada textual retornam vazio sem falsas promessas de OCR).

---

## 3. Pesquisa Técnica & Licenças

- **Nenhuma nova dependência de terceiros adicionada ao `pubspec.yaml`:** reutilizamos bibliotecas já auditadas (`drift`, `archive` BSD-3-Clause para `.zip`/zlib, `cryptography` Apache-2.0, `web` BSD-3-Clause, `pdf`/`printing` apenas geração).
- Padrão FTS5 `unicode61 remove_diacritics 2` alinhado a `lib/territory/geocoding/osm_fts_search_io.dart`.
- Padrão Callouts GFM (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`) alinhado ao formato oficial GitHub/Antigravity já adotado no repositório.

---

## 4. Plano de Testes

- `test/database_migration_test.dart`: adicionar `TC-MIG-08` (v8 -> v9 completo preservando `app_kv_store`, `email_accounts`, todas colunas Second Brain e índices).
- `test/knowledge/second_brain_domain_test.dart`:
  - Backlinks bidirecionais (inserção, atualização, exclusão, ciclo de subpáginas bloqueado);
  - Áreas P.A.R.A. + subpáginas hierárquicas + propriedades customizadas;
  - Revisão espaçada (progressão `hard`/`good`/`easy`) + agregador Revisão Semanal;
  - FTS5 / busca rankeada com acentuação + tags + texto extraído de PDF sintético com stream FlateDecode;
  - Importador do Notion (`.zip`, `.md`, `.csv`, reescrita de links internos, criação de subpáginas e enfileiramento E2EE).
- `test/ui/widgets/second_brain_editor_and_views_test.dart`:
  - Autocomplete `[[` e menu `/` slash no editor;
  - Blocos ricos (`toggle`, `callout`, `tabela`, `checklist` interativa clicável);
  - Alternância de visualizações (`Lista`, `Tabela`, `Kanban`, `Galeria`) na `KnowledgeBaseScreen`.
