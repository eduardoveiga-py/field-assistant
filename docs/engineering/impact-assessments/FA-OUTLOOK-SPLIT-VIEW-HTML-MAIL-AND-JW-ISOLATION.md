# Impact Assessment & Design: Outlook Split View, HTML Sanitizer, Sender/Account Names & JW Mail Isolation

**ID:** `FA-OUTLOOK-SPLIT-VIEW-HTML-MAIL-AND-JW-ISOLATION`  
**Data:** 23/11/2026  
**Status:** Approved for Implementation  
**Autor:** Antigravity (Google DeepMind)  
**Branch:** `feat/outlook-split-view-html-mail-and-jw-isolation`

---

## 1. Problema e Objetivo

1. **Sanitização de HTML e Renderização Rica:**
   - E-mails HTML (ex.: newsletters da Microsoft, Google, etc.) salvavam blocos `<style>` e comentários `<!-- -->` no `bodyText`. Ao exibir o texto, o app renderizava CSS bruto (`a, u + div center > a > span > span {background:...}`) e fechamentos de comentários `-->`.
   - Na lista, nos cards de Capturas e no modal/leitor, o texto ficava poluído e ilegível.
   - Anexos PDF falhavam ao abrir quando não tinham bytes em cache local ou quando o tipo vinha como `file`.

2. **Remetente e Conta:**
   - Na sincronização do Microsoft Graph, apenas o e-mail cru (`address`) era salvo no campo `from`, ignorando o nome amigável (`name`) do remetente.
   - No dropdown de contas e nos badges, exibia-se o e-mail longo em vez do nome da conta (`acc.name`).

3. **Leitor de E-mails Master-Detail Estilo Outlook:**
   - Em tablets (iPad horizontal e vertical) e desktop (`width >= 700`), o app abria um `showModalBottomSheet` apertado em vez de oferecer a experiência produtiva de painel dividido (lista à esquerda e leitura à direita com HTML rico, imagens e anexos).
   - Em celulares (`width < 700`), um leitor de tela cheia limpo substitui o modal truncado.

4. **Isolamento de `JW Mail` para Contas Exchange:**
   - Contas comuns (`gmail_api`, `microsoft_graph`, `imap`) estavam sendo categorizadas incorretamente como `email_jw` na fila de capturas e nos badges. O rótulo `JW Mail` / `email_jw` deve ser exclusivo de contas com protocolo `exchange`.

---

## 2. Decisões Arquiteturais e Componentes

1. **`EmailHtmlSanitizer` ([lib/inbox/email_html_sanitizer.dart]):**
   - Utilitário puro e reutilizável com:
     - `extractPlainText(String)`: strip de `<style>`, `<script>`, `<head>`, `<!-- -->`, conversão de quebras de bloco para `\n`, remoção de tags, decodificação completa de entidades HTML e normalização de espaços.
     - `displaySenderName(String)`: extração de nome limpo de `"Nome" <email>` ou fallback inteligente.
     - `extractEmailAddress(String)`: extração de endereço.
     - `senderInitials(String)`: iniciais determinísticas para `CircleAvatar`.
     - `sanitizeHtmlForDisplay(String)`: remoção de scripts e handlers de eventos perigosos.

2. **Renderização Rica via `flutter_widget_from_html_core`:**
   - Adicionada dependência multiplataforma leve (sem webview nativa, compatível com Web, iOS, macOS, Android, Windows e Linux).
   - `Content-Security-Policy` em `web/index.html` atualizada para permitir imagens externas seguras (`img-src 'self' data: blob: https:;`).

3. **Master-Detail Layout (`width >= 700`):**
   - Coluna esquerda: largura adaptativa (35%–38%, entre 300px e 420px), destacando visualmente o e-mail ativo.
   - Coluna direita: painel fixo de leitura estilo Outlook com cabeçalho limpo, corpo HTML rico rolável, anexos clicáveis e barra de ações rápidas (Responder, Excluir, Exportar, Virar Tarefa, Virar Pesquisa).
   - Mobile (`width < 700`): toque abre `EmailReaderScreen` em tela cheia com `Navigator.push`.

4. **Capturas e Wrap de Ações:**
   - Higienização do texto com `EmailHtmlSanitizer.extractPlainText`.
   - Substituição do `Row` horizontal por `Wrap(spacing: 8, runSpacing: 6)` para que botões de conversão nunca transbordem ou sejam cortados.

5. **Isolamento de `JW Mail` (Exchange):**
   - `EmailSyncCoordinator.persistSyncedMessages` e `JwEmailService` só atribuem `email_jw` quando `protocol == 'exchange'`. Contas OAuth/IMAP recebem `email`.
   - Rótulos exibem `acc.name` (`Hotmail`, `Gmail`, `JW Exchange`).

---

## 3. Matriz de Testes

- **Unitários:**
  - `EmailHtmlSanitizer`: remoção de CSS, comentários, tags, conversão de quebras, decodificação de entidades, extração de nome e iniciais.
  - Sincronização Microsoft: preservação de `"$name <$address>"` e sanitização de `bodyText`.
  - Isolamento de protocolo: verificação de que `gmail_api` e `microsoft_graph` geram categoria `email` e nunca `email_jw`.
  - Layout Master-Detail: verificação de renderização split em >= 700px e coluna única em < 700px sem overflow.
- **Regressão:**
  - `test/inbox/` (todos os 87+ testes).
  - `test/ui/screens/inbox_screen_test.dart` (todos os 8 testes).
  - `test/ui/ipad_adaptive_master_detail_test.dart` (todos os 3 testes).
  - `tool/pre_push.ps1` (`dart format` e `flutter analyze`).
