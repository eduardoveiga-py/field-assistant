# Impact Assessment & Design — Badge de E-mails Não Lidos na Tela Inicial

- **Task ID:** `FA-HOME-UNREAD-EMAIL-BADGE`
- **Branch:** `feat/home-unread-email-badge` (`origin/master` @ `f11f73e`)
- **Compliance:** `AGENTS.md`, `.agents/rules/field-assistant-ci-gate.md`, `.agents/skills/field-assistant-engineering-standard/SKILL.md`

---

## 1. Problem Statement & Mapping

- **Problema observado:** O ícone de Inbox no canto superior direito da tela inicial (`TodayScreen`) observava `unprocessedInboxCountProvider`, que soma todas as linhas em `inbox_entries` com `status == 'unprocessed'` e `deletedAt IS NULL`. Como todo e-mail retido permanece com `status == 'unprocessed'` mesmo após ser aberto (`isRead: true` é gravado no JSON `metadata['email']`), o badge exibia o total acumulado de e-mails em vez de apenas os **e-mails não lidos**.
- **Comportamento desejado:** O ícone no canto superior direito da `TodayScreen` deve mostrar exclusivamente a quantidade reativa de **e-mails não lidos** na caixa de entrada (excluindo lidos, rascunhos, enviados, spam, lixeira, excluídos e capturas de texto não-e-mail), ocultando o badge quando zerado.

---

## 2. Design & Affected Files

- `lib/inbox/jw_email_service.dart`: adiciona `JwEmailService.isInboxUnreadEmail(JwEmailMessage)` (reutilizando o mesmo critério de pastas de Caixa de Entrada de `InboxScreen`) e `watchUnreadEmailsCount()`.
- `lib/ui/providers.dart`: expõe `unreadEmailsCountProvider` (`StreamProvider<int>`).
- `lib/ui/screens/today_screen.dart`: atualiza apenas o `IconButton` superior direito (`btn_today_inbox_unread_badge`) mantendo `Icons.all_inbox_rounded` e visibilidade governada por `AppFeature.inbox`; atualiza o tooltip descritivo. Mantém o atalho inferior `Acesso Rápido > Inbox` vinculado a `unprocessedInboxCountProvider` (itens pendentes do Inbox Universal).
- `test/ui/screens/today_inbox_unread_badge_test.dart`: testes unitários e de widget validando filtro de pastas/status e atualização reativa ao marcar leitura.

---

## 3. Data Integrity, Offline-First, Web-Safety & Rollback

- Zero alterações de schema Drift, RLS ou fila de sincronização.
- Zero novos imports `dart:io` ou `sqlite3`.
- Streams Drift fechadas normalmente no descarte do `ProviderScope` / `AppDatabase.close()`.
- **Rollback:** reverter o commit da branch `feat/home-unread-email-badge` sem impacto em dados persistidos.
