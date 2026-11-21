# Pacotes de Terceiros (`third_party/`)

Este diretório contém dependências Dart/Flutter mantidas localmente no repositório (`path` dependencies no `pubspec.yaml`), em vez de serem consumidas diretamente do `pub.dev` ou de repositórios remotos sem controle de patches.

## Pacotes mantidos localmente

### `eas_client`
- **Finalidade:** Cliente Exchange ActiveSync (EAS) utilizado para integração e sincronização de contas corporativas (e-mail, calendário, contatos e tarefas).
- **Motivo da manutenção local:** Necessidade de correções específicas de protocolo, tratamento de respostas malformadas/vazias do servidor (ex.: distinção de status de arquivo vazio global malformado) e ajustes de compatibilidade que não estão disponíveis ou demoram a ser aceitos no pacote upstream.

### `enough_mail`
- **Finalidade:** Biblioteca de cliente de e-mail (IMAP, POP3, SMTP e MIME) usada para leitura, envio e manipulação de mensagens.
- **Motivo da manutenção local:** Aplicação de correções de estabilidade, compatibilidade com provedores específicos e ajustes necessários para o fluxo do aplicativo sem depender de ciclos externos de release.

## Por que manter em `third_party/`

1. **Previsibilidade de build:** Garante builds reproduzíveis sem risco de regressões silenciosas ou quebra por atualizações externas.
2. **Agilidade em hotfixes:** Permite corrigir bugs críticos de protocolo ou parsing diretamente no projeto e validar imediatamente junto ao app.
3. **Controle de compatibilidade:** Facilita manter versões alinhadas ao SDK Flutter/Dart e às regras de análise estática do projeto.

## Política de manutenção, testes e correções upstream

1. **Modificações locais:**
   - Toda alteração em `third_party/eas_client` ou `third_party/enough_mail` deve ser documentada na mensagem de commit e no PR correspondente, explicando o problema original e a correção aplicada.
   - Evitar refatorações amplas ou alterações cosméticas desnecessárias para facilitar futuros merges/rebases com o upstream.
2. **Testes:**
   - Correções de bug ou comportamento em pacotes de `third_party/` devem incluir testes unitários no próprio pacote (quando aplicável) e/ou testes de integração/regressão no repositório principal (`test/`).
   - Antes de abrir PR, executar `flutter analyze` e a suíte de testes relevante para garantir que não há regressões.
3. **Aplicação de correções upstream:**
   - Ao sincronizar com uma nova versão upstream, revisar o changelog e fazer diff cuidadoso para preservar todos os patches locais ainda necessários.
   - Caso um patch local tenha sido incorporado oficialmente no upstream, removê-lo do diff local e registrar a atualização no commit/PR.
   - Sempre que possível e pertinente, contribuir com correções genéricas de volta ao repositório upstream, mantendo o fork local apenas enquanto houver necessidade técnica.
