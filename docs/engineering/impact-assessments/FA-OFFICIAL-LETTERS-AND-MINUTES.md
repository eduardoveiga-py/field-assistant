# Impact Assessment & Design — Cartas Oficiais, Pautas, Atas, Perfis Reutilizáveis e Exportação Multi-Formato

- **Task ID:** `FA-OFFICIAL-LETTERS-AND-MINUTES`
- **Branch:** `feat/official-letters-and-minutes`
- **Base:** `master` (`d0026b7`)
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`, `.agent/skills/flutter-drift-architecture/SKILL.md`

---

## 1. Problem Statement & Scope

Secretários e Superintendentes de Serviço precisam redigir cartas de apresentação, correspondências gerais, pautas e atas de reunião com padrão organizacional respeitoso, elegante e consistente, reaproveitando timbre congregacional e assinaturas (da Comissão de Serviço, do Corpo de Anciãos ou individuais) sem redigitar metadados nem sair do aplicativo.

Requisitos definidos pelo usuário:
1. Acesso tanto dentro da **Base de Conhecimento** (aba dedicada `Cartas & Atas`) quanto como recurso modular no menu (**Personalizar Recursos** via `FeatureRegistry`).
2. **Perfis reutilizáveis:** seletor de **Cabeçalho** (timbre ou sem cabeçalho), seletor de **Rodapé/Assinaturas** (Comissão de Serviço, Corpo de Anciãos, Individual, Sem Assinatura), cadastro de anciãos com cargo, **fonte cursiva ou assinatura desenhada/PNG**, e customização de **fonte de tudo** (cabeçalho, metadados, corpo, assinatura, tamanho e alinhamento).
3. **7 estilos visuais selecionáveis** (com o **Padrão Original** fiel ao PDF enviado definido como padrão inicial + 6 variações institucionais/modernas/solenes).
4. **4 modelos base embutidos** (*Carta de Apresentação*, *Carta Geral / Correspondência*, *Pauta de Reunião* e *Ata de Reunião*, incluindo conversão *Pauta → Ata*) **+ capacidade de criar/salvar novos modelos personalizados** no futuro.
5. **Privacidade & Importação:** zero dados pessoais sensíveis de terceiros no repositório público do GitHub; importação de pacote JSON (ex.: exportado do Google Drive) salva permanentemente no banco local offline + sincronização E2EE.
6. **Saídas:** visualizar A4, salvar/baixar **PDF**, **PNG**, **DOCX editável** (Word / Google Docs / LibreOffice), arquivar em `Documentos` da Base de Conhecimento e **enviar por e-mail como anexo** pelo `InboxScreen` (compatível com PWA Web e nativo).

---

## 2. Architecture & Data Storage

- **Persistência sem ruptura de schema/RLS (`KnowledgeNotes` + `SyncQueue`):**
  - Documentos (`category = 'official_doc'`), modelos personalizados (`category = 'official_template'`) e o pacote de perfis/fontes/assinaturas (`category = 'official_profile_bundle'`) são gravados em `knowledge_notes` via transações Drift + `sync_queue`.
  - Mantém compatibilidade imediata com `AppDatabase` (`schemaVersion = 8`), backup/restore existente e sincronização E2EE (`supabase_sync_service.dart` / Postgres / PGlite) sem exigir migração SQL destrutiva.
  - A aba normal de Notas da Base de Conhecimento (`_buildNotesTab`), a busca de notas e `KnowledgeManager.searchKnowledge` tratam `official_*` separadamente para não exibir payloads JSON brutos ao usuário.
- **Tipografia 100% Offline (SIL OFL 1.1):**
  - Fontes estáticas `.ttf` licenciadas sob **SIL Open Font License 1.1** empacotadas em `assets/fonts/` (`PT Serif`, `Caladea`, `Crimson Text`, `PT Sans`, `Lato`, `Sacramento`, `Courgette`, `Great Vibes`, `Alex Brush`, `Allura`), garantindo renderização idêntica offline na UI Flutter, PDF (`package:pdf`) e PNG (`Printing.raster`) em Web PWA, iOS, Android, Windows, macOS e Linux.
- **Exportadores multiplataforma:**
  - **PDF:** `package:pdf` (`pw.Document` A4) sem dependência de rede.
  - **PNG:** `Printing.raster(pdfBytes, dpi: 200)` convertido página a página em PNG (`Uint8List`), mantendo fidelidade exata ao PDF.
  - **DOCX:** gerador OOXML puro em Dart usando `archive` + `xml` (`[Content_Types].xml`, `_rels/.rels`, `word/document.xml`, `word/header1.xml`, `word/footer1.xml`, `word/media/*`), editável no Microsoft Word, Google Docs e LibreOffice.
  - **Download PWA + Nativo:** extensão de `lib/reports/web_downloader*.dart` com `downloadBytes(...)` respeitando *conditional imports* (`dart.library.js_interop` / stub).

---

## 3. Security, Privacy & Rollback

- Nenhuma alteração em `ENABLE_E2EE_SYNC` (`defaultValue: false` preservado), sem `dart:io` direto em código alcançável pela Web, sem `catch (_) {}` silencioso em fluxos de e-mail/importação.
- Dados reais de congregação/cartas permanecem somente fora do repositório (importados pelo usuário a partir de JSON local/Google Drive para seu banco local offline).
- **Rollback:** desativar `AppFeature.officialDocuments` em *Personalizar* ou reverter o PR na `master` sem afetar tabelas existentes.
